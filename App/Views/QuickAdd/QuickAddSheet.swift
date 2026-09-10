import SwiftUI
import SwiftData
import PhotosUI

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedCategory: ItemCategory = .refrigerated
    @State private var selectedDate: Date? = nil
    @State private var showDatePicker = false
    @State private var nameError: String? = nil
    
    // MARK: - Custom Category States
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var showCustomCategoryAlert = false
    
    // MARK: - Reminder States
    @State private var reminder1Days: Int = 1 // Default 1 day before
    @State private var reminder2Days: Int = -1 // Default None
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    
    let reminderOptions = [
        (-1, "不提醒"),
        (0, "當天"),
        (1, "1 天前"),
        (3, "3 天前"),
        (7, "7 天前"),
        (14, "14 天前"),
        (30, "30 天前")
    ]
    
    // MARK: - OCR States
    @State private var showCamera = false
    @State private var showOCRResult = false
    @State private var capturedImage: UIImage? = nil
    @State private var ocrService = OCRService()
    
    // MARK: - Photo Picker States
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    @State private var showPaywall = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            Text("快速新增物品")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 16)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - OCR Quick Scan Button
                    ocrButtonSection
                    
                    // FIELD 1 - 物品名稱
                    VStack(alignment: .leading, spacing: 8) {
                        Text("物品名稱")
                            .font(.headline)
                        TextField("輸入名稱（例如：眼藥水、起司片）", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: name) { _, _ in nameError = nil }
                        
                        if let error = nameError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                    }
                    
                    // FIELD 2 - 分類
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分類")
                            .font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(ItemCategory.defaultCategories + categoryStore.customCategories) { category in
                                    let isCustom = categoryStore.customCategories.contains(category)
                                    CategoryPill(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        onDelete: isCustom ? {
                                            if selectedCategory == category {
                                                selectedCategory = .refrigerated
                                            }
                                            categoryStore.deleteCategory(category)
                                        } : nil
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                                
                                Button(action: { showCustomCategoryAlert = true }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("自訂")
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(UIColor.separator), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 4) // Prevent left/right stroke clipping
                            .padding(.vertical, 4)   // Prevent top/bottom stroke clipping
                        }
                    }
                    
                    // FIELD 3 - 效期快選
                    VStack(alignment: .leading, spacing: 8) {
                        Text("效期快選")
                            .font(.headline)
                        HStack {
                            quickDateButton(title: "+3 天", days: 3)
                            quickDateButton(title: "+7 天", days: 7)
                            quickDateButton(title: "+1 個月", months: 1)
                            quickDateButton(title: "+半年", months: 6)
                        }
                    }
                    
                    // DATE DISPLAY
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                        Text(selectedDate != nil ? DateHelpers.formatDate(selectedDate!) : "點擊上方快選或自訂日期")
                            .font(.system(size: 15, weight: selectedDate != nil ? .semibold : .regular))
                            .foregroundColor(selectedDate != nil ? .primary : .secondary)
                        Spacer()
                        
                        DatePicker("", selection: Binding(
                            get: { selectedDate ?? Date() },
                            set: { selectedDate = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_Hant_TW"))
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
                    
                    // FIELD 4 - 提醒設定
                    reminderSection
                }
                .padding(.horizontal)
            }
            
            // SUBMIT BUTTON
            Button(action: submit) {
                Text("加入防過期清單")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding()
        }
        // MARK: - Camera Sheet
        .fullScreenCover(isPresented: $showCamera) {
            CameraScannerView(
                onImageCaptured: { image in
                    capturedImage = image
                    showCamera = false
                    showOCRResult = true
                    Task {
                        await ocrService.recognizeExpiryDate(from: image)
                    }
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        // MARK: - OCR Result Sheet
        .sheet(isPresented: $showOCRResult) {
            if let image = capturedImage {
                OCRResultView(
                    image: image,
                    service: ocrService,
                    onDateSelected: { date in
                        selectedDate = date
                        showOCRResult = false
                    },
                    onDismiss: {
                        showOCRResult = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        // MARK: - Paywall Sheet
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // MARK: - Custom Category Sheet
        .sheet(isPresented: $showCustomCategoryAlert) {
            CustomCategorySheet(
                selectedCategory: $selectedCategory,
                isPresented: $showCustomCategoryAlert
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-screenshot-quickadd") {
                self.name = "日清海鮮風味杯麵"
                self.selectedCategory = .snacks
                self.selectedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18))
            } else if ProcessInfo.processInfo.arguments.contains("-screenshot-custom-category") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.showCustomCategoryAlert = true
                }
            } else if ProcessInfo.processInfo.arguments.contains("-screenshot-ocr") {
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 260))
                let testImg = renderer.image { ctx in
                    UIColor(white: 0.95, alpha: 1.0).setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 260))
                    
                    let bgRect = CGRect(x: 20, y: 20, width: 360, height: 220)
                    UIColor(white: 0.88, alpha: 1.0).setFill()
                    UIBezierPath(roundedRect: bgRect, cornerRadius: 16).fill()
                    
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .bold),
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: paragraphStyle
                    ]
                    let str = "PROD : 2024/12/31\nEXP  : 2026/12/31"
                    str.draw(in: CGRect(x: 20, y: 95, width: 360, height: 80), withAttributes: titleAttrs)
                }
                self.capturedImage = testImg
                self.ocrService.recognizedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 31))
                self.ocrService.recognizedReason = "✅ 精準辨識出有效日期"
                self.ocrService.suggestedProductName = "日清海鮮風味杯麵"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showOCRResult = true
                }
            }
        }
    }
    
    // MARK: - OCR Button Section
    
    @ViewBuilder
    private var ocrButtonSection: some View {
        VStack(spacing: 10) {
            // Camera button
            Button(action: {
                if StoreManager.shared.hasUnlockedPro {
                    showCamera = true
                } else {
                    showPaywall = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("拍照辨識效期")
                                .font(.headline)
                            if !StoreManager.shared.hasUnlockedPro {
                                Text("PRO")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                            }
                        }
                        Text("對準包裝，自動讀取到期日")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green.opacity(0.8), .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            }
            
            // Photo library button
            if StoreManager.shared.hasUnlockedPro {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("從相簿選擇照片")
                                .font(.headline)
                            Text("選擇已拍好的照片來辨識到期日")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }
                .onChange(of: selectedPhotoItem) { _, newValue in
                    guard let newValue else { return }
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            capturedImage = image
                            await ocrService.recognizeExpiryDate(from: image)
                            showOCRResult = true
                        }
                        selectedPhotoItem = nil
                    }
                }
            } else {
                Button(action: {
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("從相簿選擇照片")
                                    .font(.headline)
                                Text("PRO")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                            }
                            Text("選擇已拍好的照片來辨識到期日")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Quick Date Buttons
    
    private func quickDateButton(title: String, days: Int = 0, months: Int = 0) -> some View {
        let isMatchingDate: Bool = {
            guard let sel = selectedDate else { return false }
            let target: Date
            if days > 0 {
                target = DateHelpers.addDays(days, to: Date())
            } else if months > 0 {
                target = DateHelpers.addMonths(months, to: Date())
            } else {
                return false
            }
            return Calendar.current.isDate(sel, inSameDayAs: target)
        }()
        
        return Button(action: {
            if days > 0 {
                selectedDate = DateHelpers.addDays(days, to: Date())
            } else if months > 0 {
                selectedDate = DateHelpers.addMonths(months, to: Date())
            }
        }) {
            Text(title)
                .font(.subheadline.weight(isMatchingDate ? .semibold : .regular))
                .foregroundColor(isMatchingDate ? .green : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isMatchingDate ? Color.green.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isMatchingDate ? Color.green : Color(UIColor.separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Reminder Section
    
    @ViewBuilder
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提醒設定")
                .font(.headline)
            
            HStack {
                Text("提醒時間")
                    .foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
            
            HStack {
                Text("第一提醒")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("第一提醒", selection: $reminder1Days) {
                    ForEach(reminderOptions, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
            
            HStack {
                Text("第二提醒")
                    .foregroundColor(.secondary)
                Spacer()
                Picker("第二提醒", selection: $reminder2Days) {
                    ForEach(reminderOptions, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Submit
    
    private func submit() {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = "請輸入物品名稱"
            return
        }
        guard let date = selectedDate else {
            nameError = "請選擇到期日"
            return
        }
        
        let item = TrackedItem(name: name, category: selectedCategory, expiryDate: date)
        item.reminder1Days = reminder1Days
        item.reminder2Days = reminder2Days
        item.reminderTime = reminderTime
        modelContext.insert(item)
        
        let validReminders = [reminder1Days, reminder2Days].filter { $0 >= 0 }
        
        Task {
            await NotificationService.shared.scheduleExpiryReminders(
                itemID: item.id,
                itemName: item.name,
                expiryDate: item.expiryDate,
                reminderDays: validReminders,
                reminderTime: reminderTime
            )
        }
        
        dismiss()
    }
}

// MARK: - Custom Category Sheet

struct CustomCategorySheet: View {
    @Binding var selectedCategory: ItemCategory
    @Binding var isPresented: Bool
    
    @State private var categoryName: String = ""
    @State private var selectedEmoji: String = "🍏"
    
    let emojiOptions: [String] = {
        let foods = "🍏🍎🍐🍊🍋🍌🍉🍇🍓🍈🍒🍑🥭🍍🥥🥝🍅🍆🥑🥦🥬🥒🌶🌽🥕🧄🧅🥔🍠🥐🥯🍞🥖🥨🧀🥚🍳🧈🥞🧇🥓🥩🍗🍖🦴🌭🍔🍟🍕🥪🥙🧆🌮🌯🥗🥘🥫🍝🍜🍲🍛🍣🍱🥟🦪🍤🍙🍚🍘🍥🥠🥮🍢🍡🍧🍨🍦🥧🧁🍰🎂🍮🍭🍬🍫🍿🍩🍪🌰🥜🍯🥛🍼☕️🍵🧃🥤🍶🍺🍻🥂🍷🥃🍸🍹🧉🍾🧊"
        let objects = "⌚️📱📲💻⌨️🖥🖨🖱🖲🕹🗜💽💾💿📀📼📷📸📹🎥📽🎞📞☎️📟📠📺📻🎙🎚🎛🧭⏱⏲⏰🕰⌛️⏳📡🔋🔌💡🔦🕯🪔🧯🛢💸💵💴💶💷💰💳💎⚖️🧰🔧🔨⚒🛠⛏🔩⚙️🧱⛓🧲💣🧨🪓🔪🗡⚔️🛡🚬⚰️⚱️🏺🔮📿🧿💈⚗️🔭🔬🕳🩹🩺💊💉🩸🧬🦠🧫🧪🌡🧹🧺🧻🚽🚰🚿🛁🛀🧼🪒🧽🧴🛎🔑🗝🚪🪑🛋🛏🛌🧸🖼🛍🛒🎁🎈🎏🎀🪄🪆🪞🪟"
        let clothing = "👕👖🩲🩳👔👗👙👘🥻🩱🥿👠👡👢👞👟🥾🧦🧤🧣🎩🧢👒🎓⛑👑💍👝👛👜💼🎒🧳👓🕶🥽🌂"
        let nature = "🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🐤🐣🦇🦉🦅🦆🦢🕊🦩🦚🦜🐸🐊🐢🦎🐍🐲🦕🦖🐳🐬🐟🐠🐡🦈🐙🐚🐌🦋🐛🐜🐝🐞🦗🕷🦂🦟🦠💐🌸💮🏵🌹🥀🌺🌻🌼🌷🌱🌲🌳🌴🌵🌾🌿☘️🍀🍁🍂🍃🍄"
        
        let all = foods + objects + clothing + nature
        return all.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }()
    
    let columns = [GridItem(.adaptive(minimum: 48))]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header: Selected Emoji Preview & Name Input
                HStack(spacing: 16) {
                    // Selected Emoji Box
                    VStack(spacing: 4) {
                        Text(selectedEmoji)
                            .font(.system(size: 38))
                            .frame(width: 60, height: 60)
                            .background(Color.green.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                        Text("目前圖示")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分類名稱")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("例如：零食、文具、化妝品", text: $categoryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Divider()
                    .padding(.horizontal)
                
                // Emoji Picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("點擊選擇圖示")
                            .font(.headline)
                        Spacer()
                        Text("共 \(emojiOptions.count) 種圖示")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                }) {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 46, height: 46)
                                        .background(selectedEmoji == emoji ? Color.green.opacity(0.25) : Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedEmoji == emoji ? Color.green : Color(UIColor.separator), lineWidth: selectedEmoji == emoji ? 2 : 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("新增自訂分類")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = name.isEmpty ? "自訂分類" : name
                        let newCategory = ItemCategory(emoji: selectedEmoji, name: finalName)
                        
                        CategoryStore.shared.addCategory(newCategory)
                        selectedCategory = newCategory
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
