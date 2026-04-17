import SwiftUI

struct UserManualView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: ManualTopic = .overview

    var body: some View {
        NavigationSplitView {
            topicList
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            ScrollView {
                topicDetail(selectedTopic)
                    .padding(24)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(12)
            }
        }
        .frame(width: 900, height: 680)
    }

    // MARK: - Topic List

    private var topicList: some View {
        List(ManualTopic.allCases, selection: $selectedTopic) { topic in
            Label(LocalizedStringKey(topic.title), systemImage: topic.icon)
                .tag(topic)
        }
        .listStyle(.sidebar)
        .navigationTitle("사용자 가이드")
    }

    // MARK: - Topic Detail

    @ViewBuilder
    private func topicDetail(_ topic: ManualTopic) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: topic.icon)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text(LocalizedStringKey(topic.title))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Divider()

            ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
    }

    private func sectionView(_ section: ManualSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(LocalizedStringKey(title))
                    .font(.headline)
            }

            Text(LocalizedStringKey(section.body))
                .font(.body)
                .foregroundStyle(.secondary)

            if !section.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.items, id: \.key) { item in
                        ManualKeyValueRow(key: item.key, value: item.value, symbolName: item.symbolName, symbolColor: item.symbolColor)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let note = section.note {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                    Text(LocalizedStringKey(note))
                        .font(.callout)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - Key-Value Row

private struct ManualKeyValueRow: View {
    let key: String
    let value: String
    var symbolName: String? = nil
    var symbolColor: Color? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(symbolColor ?? .primary)
                    .frame(width: 28, height: 20)
            } else {
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
            }
            Text(LocalizedStringKey(value))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Models

struct ManualSection {
    let title: String?
    let body: String
    let items: [KeyValueItem]
    let note: String?

    init(title: String? = nil, body: String = "", items: [KeyValueItem] = [], note: String? = nil) {
        self.title = title
        self.body = body
        self.items = items
        self.note = note
    }
}

struct KeyValueItem {
    let key: String
    let value: String
    var symbolName: String? = nil
    var symbolColor: Color? = nil
}

// MARK: - Topics

enum ManualTopic: String, CaseIterable, Identifiable {
    case overview
    case projects
    case chat
    case shortcuts
    case slashCommands
    case attachments
    case customShortcuts
    case inspectorPanel
    case github
    case marketplace
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:        "Clarc 소개"
        case .projects:        "프로젝트 관리"
        case .chat:            "채팅 기본"
        case .shortcuts:       "키보드 단축키"
        case .slashCommands:   "슬래시 명령어"
        case .attachments:     "파일 및 이미지 첨부"
        case .customShortcuts: "단축 버튼"
        case .inspectorPanel:  "인스펙터 패널"
        case .github:          "GitHub 연동"
        case .marketplace:     "스킬 마켓플레이스"
        case .permissions:     "권한 요청"
        }
    }

    var icon: String {
        switch self {
        case .overview:        "sparkle"
        case .projects:        "folder.fill"
        case .chat:            "bubble.left.and.bubble.right"
        case .shortcuts:       "keyboard"
        case .slashCommands:   "terminal.fill"
        case .attachments:     "paperclip"
        case .customShortcuts: "bolt.fill"
        case .inspectorPanel:  "sidebar.trailing"
        case .github:          "building.columns"
        case .marketplace:     "brain.head.profile"
        case .permissions:     "checkmark.shield"
        }
    }

    var sections: [ManualSection] {
        switch self {
        case .overview:
            [
                ManualSection(
                    title: "Clarc이란?",
                    body: "Claude Code CLI의 네이티브 macOS 데스크톱 클라이언트입니다. 터미널 없이 GUI로 Claude Code의 모든 기능을 사용할 수 있습니다."
                ),
                ManualSection(
                    title: "기본 레이아웃",
                    body: "왼쪽 사이드바에는 히스토리와 파일 탭이 있습니다. 프로젝트 탭은 채팅 영역 상단에 표시됩니다. 오른쪽 인스펙터 패널에는 터미널과 메모 탭이 있습니다.",
                    note: "프로젝트를 선택하지 않으면 채팅이 비활성화됩니다."
                ),
                ManualSection(
                    title: "상단 툴바",
                    body: "툴바에는 새 채팅, 슬래시 명령어 관리, 단축 버튼 관리, 권한 모드 선택기, 모델 선택기, 인스펙터 패널 토글, 설정, GitHub 연동 버튼이 있습니다."
                ),
            ]

        case .projects:
            [
                ManualSection(
                    title: "프로젝트 추가",
                    body: "사이드바 상단의 + 버튼을 클릭하거나 Finder에서 폴더를 드래그하세요. Claude Code는 해당 폴더를 작업 디렉토리로 사용합니다."
                ),
                ManualSection(
                    title: "프로젝트 탭",
                    body: "프로젝트 탭은 채팅 영역 상단에 표시됩니다. 탭을 클릭하면 프로젝트를 전환할 수 있습니다. Claude가 스트리밍 중에도 전환할 수 있으며, 활성 스트림은 백그라운드에서 계속 실행됩니다."
                ),
                ManualSection(
                    title: "독립 프로젝트 창",
                    body: "프로젝트 탭을 더블클릭하면 별도의 독립 창으로 열립니다. 각 창은 세션을 독립적으로 관리하므로 여러 프로젝트를 동시에 작업할 수 있습니다.",
                    note: "독립 프로젝트 창에서는 프로젝트 이름만 표시되며 프로젝트 탭이 없습니다."
                ),
                ManualSection(
                    title: "사이드바 탭",
                    body: "히스토리 탭: 이전 대화 목록\n파일 탭: 프로젝트 파일 트리 탐색",
                    items: [
                        KeyValueItem(key: "⌘1", value: "히스토리 탭으로 이동"),
                        KeyValueItem(key: "⌘2", value: "파일 탭으로 이동"),
                        KeyValueItem(key: "⌘F", value: "파일 탭 + 검색 활성화"),
                    ]
                ),
                ManualSection(
                    title: "히스토리 관리",
                    body: "히스토리 탭에서 세션을 우클릭하면 컨텍스트 메뉴가 열립니다.",
                    items: [
                        KeyValueItem(key: "pin", value: "고정 / 해제 — 고정된 세션은 목록 상단에 유지됩니다", symbolName: "pin.fill", symbolColor: .orange),
                        KeyValueItem(key: "rename", value: "이름 변경 — 세션 제목을 수정합니다", symbolName: "pencil", symbolColor: .secondary),
                        KeyValueItem(key: "delete", value: "삭제 — 세션을 제거합니다", symbolName: "trash", symbolColor: .red),
                    ],
                    note: "히스토리 헤더의 휴지통 아이콘을 클릭하면 모든 세션을 한 번에 삭제할 수 있습니다."
                ),
                ManualSection(
                    title: "파일 인스펙터",
                    body: "파일 탭에서 파일을 클릭하면 구문 강조와 함께 미리보기가 표시됩니다. 연필 버튼을 누르면 편집 모드로 전환되어 파일을 직접 수정할 수 있습니다.",
                    items: [
                        KeyValueItem(key: "⌘S", value: "파일 변경 사항 저장"),
                        KeyValueItem(key: "Escape", value: "편집 모드 종료"),
                    ],
                    note: "1 MB를 초과하는 파일은 미리보기가 지원되지 않습니다."
                ),
                ManualSection(
                    title: "Git 상태",
                    body: "변경된 파일 수가 사이드바 하단에 표시됩니다."
                ),
            ]

        case .chat:
            [
                ManualSection(
                    title: "메시지 보내기",
                    body: "입력 필드에 메시지를 입력하고 Return 키 또는 전송 버튼을 누르세요.",
                    items: [
                        KeyValueItem(key: "Return", value: "메시지 전송"),
                        KeyValueItem(key: "⌘Return", value: "메시지 전송 (대체 단축키)"),
                        KeyValueItem(key: "⇧Return", value: "줄 바꿈 삽입"),
                        KeyValueItem(key: "Escape", value: "스트리밍 중단 (응답 생성 취소)"),
                    ]
                ),
                ManualSection(
                    title: "메시지 큐",
                    body: "Claude가 응답 중에도 메시지를 보낼 수 있습니다. 새 메시지는 자동으로 큐에 추가되어 현재 응답이 완료되면 전송됩니다. 큐에 쌓인 메시지는 입력 필드 위에 뱃지로 표시됩니다. 각 항목의 × 버튼을 클릭하면 큐에서 제거됩니다."
                ),
                ManualSection(
                    title: "이전 메시지 불러오기",
                    body: "입력 필드가 비어 있을 때 ↑/↓ 키로 메시지 히스토리를 탐색할 수 있습니다.",
                    items: [
                        KeyValueItem(key: "↑", value: "이전 메시지 불러오기"),
                        KeyValueItem(key: "↓", value: "다음 메시지 / 입력 초기화"),
                    ]
                ),
                ManualSection(
                    title: "모델 변경",
                    body: "채팅 영역 상단의 모델 드롭다운에서 Claude 모델을 전환할 수 있습니다."
                ),
                ManualSection(
                    title: "권한 모드",
                    body: "채팅 영역 상단의 권한 모드 드롭다운에서 Claude가 작업을 실행하기 전에 승인을 요청하는 방식을 제어할 수 있습니다.",
                    items: [
                        KeyValueItem(key: "권한 요청", value: "기본 모드 — 파일 편집과 명령어 실행 시 승인 요청"),
                        KeyValueItem(key: "편집 수락", value: "작업 디렉토리 파일 편집을 자동 수락 (명령어는 여전히 승인 필요)"),
                        KeyValueItem(key: "계획 모드", value: "파일 읽기만 허용, 실제 편집 없이 계획만 제시"),
                        KeyValueItem(key: "권한 건너뛰기", value: "모든 권한 검사 생략 — 격리된 환경에서만 사용 권장"),
                    ],
                    note: "권한 건너뛰기 모드는 완전히 신뢰하는 프로젝트에서만 사용하세요."
                ),
            ]

        case .shortcuts:
            [
                ManualSection(
                    title: "전역 단축키",
                    body: "",
                    items: [
                        KeyValueItem(key: "⌘N", value: "새 채팅 시작"),
                        KeyValueItem(key: "⌘W", value: "현재 창 닫기"),
                        KeyValueItem(key: "⌘1", value: "사이드바 — 히스토리 탭 (숨겨진 경우 펼침)"),
                        KeyValueItem(key: "⌘2", value: "사이드바 — 파일 탭 (숨겨진 경우 펼침)"),
                        KeyValueItem(key: "⌘3", value: "왼쪽 사이드바 토글"),
                        KeyValueItem(key: "⌘4", value: "오른쪽 인스펙터 패널 토글"),
                        KeyValueItem(key: "⌘F", value: "사이드바 — 파일 탭 + 검색 활성화"),
                        KeyValueItem(key: "더블클릭", value: "프로젝트 탭 — 독립 창으로 열기"),
                    ]
                ),
                ManualSection(
                    title: "입력 필드 단축키",
                    body: "",
                    items: [
                        KeyValueItem(key: "Return", value: "메시지 전송"),
                        KeyValueItem(key: "⌘Return", value: "메시지 전송 (대체 단축키)"),
                        KeyValueItem(key: "⇧Return", value: "줄 바꿈"),
                        KeyValueItem(key: "Escape", value: "팝업 닫기 / 스트리밍 중단"),
                        KeyValueItem(key: "↑ / ↓", value: "팝업 항목 선택 또는 메시지 히스토리 탐색"),
                        KeyValueItem(key: "Tab", value: "슬래시 명령어 / @ 파일 자동완성"),
                    ]
                ),
                ManualSection(
                    title: "슬래시 명령어 팝업",
                    body: "",
                    items: [
                        KeyValueItem(key: "↑ / ↓", value: "항목 선택"),
                        KeyValueItem(key: "Return", value: "명령어 실행"),
                        KeyValueItem(key: "⌘Return", value: "명령어 상세 보기"),
                        KeyValueItem(key: "Tab", value: "명령어 자동완성"),
                        KeyValueItem(key: "Escape", value: "팝업 닫기"),
                    ]
                ),
                ManualSection(
                    title: "@ 파일 팝업",
                    body: "",
                    items: [
                        KeyValueItem(key: "↑ / ↓", value: "항목 선택"),
                        KeyValueItem(key: "Return / Tab", value: "파일 경로 삽입"),
                        KeyValueItem(key: "Escape", value: "팝업 닫기"),
                    ]
                ),
            ]

        case .slashCommands:
            [
                ManualSection(
                    title: "슬래시 명령어란?",
                    body: "입력 필드에 /를 입력하면 사용 가능한 명령어 팝업이 열립니다. 슬래시 명령어를 사용하면 Claude Code CLI 작업을 직접 타이핑하지 않고 빠르게 실행할 수 있습니다."
                ),
                ManualSection(
                    title: "사용 방법",
                    body: "/를 입력해 팝업을 열고, 계속 입력하면 결과가 필터링됩니다. ↑/↓로 탐색하세요.",
                    items: [
                        KeyValueItem(key: "Return", value: "선택한 명령어 실행"),
                        KeyValueItem(key: "⌘Return", value: "명령어 상세 보기"),
                        KeyValueItem(key: "Tab", value: "명령어 자동완성"),
                        KeyValueItem(key: "Escape", value: "팝업 닫기"),
                    ]
                ),
                ManualSection(
                    title: "인터랙티브 명령어",
                    body: "/config, /permissions, /model 등 일부 명령어는 전체 인터랙티브 터미널 팝업 시트에서 실행됩니다. 명령어가 완료되면 팝업이 자동으로 닫힙니다."
                ),
                ManualSection(
                    title: "명령어 관리",
                    body: "툴바의 / 버튼을 클릭하거나 설정 → 슬래시 명령어에서 명령어를 추가, 편집, 숨기거나 비활성화할 수 있습니다. 커스텀 명령어와 기본 명령어 변경사항은 프로젝트별로 저장됩니다.",
                    note: "JSON 가져오기/내보내기로 명령어 설정을 백업하거나 공유할 수 있습니다."
                ),
            ]

        case .attachments:
            [
                ManualSection(
                    title: "파일 첨부",
                    body: "입력 필드 왼쪽의 클립 아이콘을 클릭하거나 입력 필드 위로 파일을 드래그 앤 드롭하세요. 드래그 시 드롭 영역을 나타내는 강조 테두리가 표시됩니다."
                ),
                ManualSection(
                    title: "클립보드 감지",
                    body: "붙여넣기(⌘V)는 스마트하게 동작합니다. Clarc이 클립보드 내용을 자동으로 감지해 처리합니다.",
                    items: [
                        KeyValueItem(key: "image", value: "이미지 데이터(PNG/TIFF) → 이미지로 첨부", symbolName: "photo", symbolColor: .blue),
                        KeyValueItem(key: "file", value: "파일 경로 → 파일로 첨부", symbolName: "doc", symbolColor: .secondary),
                        KeyValueItem(key: "url", value: "URL → URL 참조로 첨부", symbolName: "link", symbolColor: .accentColor),
                        KeyValueItem(key: "text", value: "긴 텍스트(2 KB 초과) → 텍스트 첨부 파일로 변환", symbolName: "text.alignleft", symbolColor: .secondary),
                    ],
                    note: "스크린샷을 직접 붙여넣으면 이미지로 자동 첨부됩니다."
                ),
                ManualSection(
                    title: "@ 파일 참조",
                    body: "입력 필드에 @를 입력하면 프로젝트 파일 검색 팝업이 열립니다. 입력할수록 실시간으로 파일이 필터링됩니다.",
                    items: [
                        KeyValueItem(key: "↑ / ↓", value: "항목 선택"),
                        KeyValueItem(key: "Return / Tab", value: "메시지에 파일 경로 삽입"),
                        KeyValueItem(key: "Escape", value: "팝업 닫기"),
                    ]
                ),
            ]

        case .customShortcuts:
            [
                ManualSection(
                    title: "단축 버튼이란?",
                    body: "채팅 영역 상단에 표시되는 빠른 접근 버튼입니다. 자주 사용하는 메시지나 셸 명령어를 클릭 한 번으로 실행할 수 있습니다."
                ),
                ManualSection(
                    title: "단축 버튼 추가",
                    body: "툴바의 ⚡ 버튼을 클릭해 단축 버튼 관리자를 열거나, 단축 버튼 바 오른쪽의 + 버튼을 누르세요. 이름, 메시지/명령어, 아이콘, 색상을 설정할 수 있습니다."
                ),
                ManualSection(
                    title: "터미널 명령어 모드",
                    body: "\"터미널 명령어로 실행\" 옵션을 활성화하면 채팅 메시지로 전송하는 대신 인스펙터 터미널에서 셸 명령어로 실행됩니다. 프로젝트 디렉토리가 작업 디렉토리로 사용됩니다."
                ),
                ManualSection(
                    title: "단축 버튼 관리",
                    body: "설정 → 단축 버튼에서 순서 변경, 편집, 삭제를 할 수 있습니다. 단축 버튼 설정은 프로젝트별로 저장됩니다.",
                    note: "JSON 가져오기/내보내기로 단축 버튼 설정을 백업하거나 공유할 수 있습니다."
                ),
            ]

        case .inspectorPanel:
            [
                ManualSection(
                    title: "인스펙터 패널 열기",
                    body: "툴바 오른쪽 상단의 ⊟ 버튼을 클릭하면 인스펙터 패널이 토글됩니다. 패널은 창 오른쪽에 도킹되며 터미널과 메모 두 탭으로 구성됩니다."
                ),
                ManualSection(
                    title: "터미널 탭",
                    body: "현재 프로젝트 디렉토리에서 시작하는 내장 zsh 터미널입니다. 앱을 벗어나지 않고 셸 명령어 실행, 파일 확인, git 관리 등을 할 수 있습니다."
                ),
                ManualSection(
                    title: "메모 탭",
                    body: "프로젝트별 리치 텍스트 메모 편집기입니다. 잠시 멈추면 자동 저장되며 세션 간에 유지됩니다. 마크다운 서식이 지원됩니다.",
                    items: [
                        KeyValueItem(key: "#", value: "제목 수준 (# / ## / ###)"),
                        KeyValueItem(key: "**text**", value: "굵게"),
                        KeyValueItem(key: "*text*", value: "기울임"),
                        KeyValueItem(key: "`code`", value: "인라인 코드"),
                        KeyValueItem(key: "~~text~~", value: "취소선"),
                        KeyValueItem(key: "- item", value: "순서 없는 목록 (Return 시 자동 계속)"),
                    ]
                ),
                ManualSection(
                    title: "인터랙티브 터미널 팝업",
                    body: "/config, /permissions, /model 등 일부 슬래시 명령어는 별도 인터랙티브 터미널 시트에서 실행됩니다. 명령어가 완료되면 팝업이 자동으로 닫힙니다.",
                    note: "하단에 종료 코드가 표시됩니다. \"exit 0\"은 명령어가 성공적으로 완료됐음을 의미합니다."
                ),
            ]

        case .github:
            [
                ManualSection(
                    title: "GitHub 연동",
                    body: "사이드바 상단의 GitHub 버튼을 클릭하면 GitHub 패널이 열립니다. GitHub 계정을 연결하면 리포지토리 목록이 표시되고 클릭 한 번으로 Clarc에 추가할 수 있습니다."
                ),
                ManualSection(
                    title: "리포지토리 추가",
                    body: "이름으로 리포지토리를 검색한 뒤 추가를 클릭하세요. Clarc이 자동으로 클론하고 새 프로젝트로 열립니다.",
                    items: [
                        KeyValueItem(key: "lock", value: "비공개 리포지토리", symbolName: "lock", symbolColor: .secondary),
                        KeyValueItem(key: "globe", value: "공개 리포지토리", symbolName: "globe", symbolColor: .secondary),
                        KeyValueItem(key: "checkmark", value: "Clarc에 이미 추가됨", symbolName: "checkmark.circle.fill", symbolColor: .green),
                    ]
                ),
            ]

        case .marketplace:
            [
                ManualSection(
                    title: "스킬 마켓플레이스",
                    body: "툴바의 🧠 아이콘을 클릭하면 Anthropic GitHub에 게시된 MCP 플러그인 카탈로그를 탐색할 수 있습니다. 카테고리로 필터링하거나 이름, 설명, 작성자로 검색할 수 있습니다."
                ),
                ManualSection(
                    title: "플러그인 설치",
                    body: "플러그인을 클릭해 상세 정보를 확인한 뒤 설치를 누르세요. 인터랙티브 터미널 팝업이 열리고 설치 명령어가 자동으로 실행됩니다.",
                    items: [
                        KeyValueItem(key: "clock", value: "미설치", symbolName: "clock", symbolColor: .secondary),
                        KeyValueItem(key: "arrow.down", value: "설치 중…", symbolName: "arrow.down.circle", symbolColor: .accentColor),
                        KeyValueItem(key: "checkmark", value: "설치됨", symbolName: "checkmark.circle.fill", symbolColor: .green),
                    ],
                    note: "카탈로그는 5분마다 자동으로 새로고침됩니다."
                ),
            ]

        case .permissions:
            [
                ManualSection(
                    title: "권한 요청이란?",
                    body: "Claude가 파일을 편집하거나 명령어를 실행하기 전에 승인을 요청합니다. 도구 이름과 인자를 보여주는 모달이 표시됩니다."
                ),
                ManualSection(
                    title: "승인 옵션",
                    body: "각 권한 요청에는 세 가지 선택지가 있습니다.",
                    items: [
                        KeyValueItem(key: "Allow", value: "이 단일 작업만 승인"),
                        KeyValueItem(key: "Allow Session", value: "현재 세션에서 동일한 유형의 모든 요청을 승인"),
                        KeyValueItem(key: "Deny", value: "작업 거절"),
                    ],
                    note: "아무 조치를 취하지 않으면 5분 후 자동으로 거부됩니다. Return 키로 허용, Escape 키로 거부할 수 있습니다."
                ),
                ManualSection(
                    title: "권한 모드",
                    body: "채팅 영역 상단의 권한 모드 드롭다운에서 Claude의 권한 처리 방식을 전환할 수 있습니다.",
                    items: [
                        KeyValueItem(key: "권한 요청", value: "기본 모드 — 파일 편집과 명령어 실행 시 승인 요청"),
                        KeyValueItem(key: "편집 수락", value: "작업 디렉토리 파일 편집을 자동 수락 (명령어는 여전히 승인 필요)"),
                        KeyValueItem(key: "계획 모드", value: "파일 읽기만 허용, 실제 편집 없이 분석과 계획만 제시"),
                        KeyValueItem(key: "권한 건너뛰기", value: "모든 권한 검사 생략 — .git/.vscode/.claude 디렉토리 쓰기는 여전히 승인 필요"),
                    ],
                    note: "권한 건너뛰기 모드는 완전히 신뢰하는 프로젝트에서만 사용하세요. 모드 변경은 다음 메시지 전송부터 적용됩니다."
                ),
            ]
        }
    }
}

#Preview {
    UserManualView()
}
