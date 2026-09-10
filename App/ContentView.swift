import SwiftUI
import SwiftData

enum Page {
    case home
    case archive
}

struct ContentView: View {
    @State private var currentPage: Page = .home
    @State private var showAddSheet = false
    @State private var showPaywall = false
    @State private var showOCRModal = false
    @Query private var trackedItems: [TrackedItem]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Main Content
            VStack {
                switch currentPage {
                case .home:
                    RadarDashboardView()
                case .archive:
                    ArchiveView()
                }
            }
            .padding(.bottom, 60)
            
            // Bottom Nav Bar
            VStack(spacing: 0) {
                Divider()
                HStack {
                    // Home Tab
                    Button(action: { currentPage = .home }) {
                        VStack(spacing: 4) {
                            Image(systemName: "dot.radiowaves.up.forward")
                            Text("首頁")
                                .font(.caption)
                        }
                        .foregroundColor(currentPage == .home ? .green : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Add Button
                    Button(action: {
                        if StoreManager.shared.canAddItem(currentCount: trackedItems.count) {
                            showAddSheet = true
                        } else {
                            showPaywall = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 56, height: 56)
                                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: -12)
                    
                    // Archive Tab
                    Button(action: { currentPage = .archive }) {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.square")
                            Text("歷史")
                                .font(.caption)
                        }
                        .foregroundColor(currentPage == .archive ? .green : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 60)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }
            .background(Color(UIColor.secondarySystemGroupedBackground).ignoresSafeArea(edges: .bottom))
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showAddSheet) {
            QuickAddSheet()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showOCRModal) {
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
            let service = OCRService()
            let _ = {
                service.recognizedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 31))
                service.recognizedReason = "✅ 依包裝噴墨特徵辨識出有效日期"
                service.suggestedProductName = "日清海鮮風味杯麵"
            }()
            OCRResultView(
                image: testImg,
                service: service,
                onDateSelected: { _ in showOCRModal = false },
                onDismiss: { showOCRModal = false }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-screenshot-archive") {
                currentPage = .archive
            } else if args.contains("-screenshot-quickadd") || args.contains("-screenshot-custom-category") {
                showAddSheet = true
            } else if args.contains("-screenshot-ocr") {
                showOCRModal = true
            } else if args.contains("-screenshot-paywall") {
                showPaywall = true
            }
        }
    }
}
