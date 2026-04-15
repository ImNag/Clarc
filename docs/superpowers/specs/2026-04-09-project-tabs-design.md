# Project Tabs Design

**Date:** 2026-04-09
**Status:** Approved

## Problem

프로젝트가 여러 개일 때 전환이 불편하다:
- 사이드바 드롭다운을 마우스로 열어야만 전환 가능 (키보드 미지원)
- 프로젝트 전환 시 마지막으로 보던 세션으로 자동 복귀되지 않음

## Solution

채팅뷰 상단 툴바(`toolbarArea`)의 정적 프로젝트명 표시를 클릭 가능한 프로젝트 탭으로 교체한다.

## UI 변경

### Before
```
[📁 ProjectName]                    [볼트 아이콘] [모델 피커]
```

### After
```
[Tab1] [Tab2(선택됨)] [Tab3]         [볼트 아이콘] [모델 피커]
```

- 각 탭: 폴더 아이콘 + 프로젝트 폴더명
- 선택된 탭: 액센트 컬러 배경 + textOnAccent 텍스트
- 미선택 탭: surfaceSecondary 배경 + textSecondary 텍스트
- 탭이 많을 경우 수평 스크롤 (`ScrollView(.horizontal)`)
- 프로젝트 추가 버튼(+) 없음 — 사이드바에서만 추가

### 사이드바 변경
`MainView.swift`의 사이드바 상단 프로젝트 드롭다운 메뉴 제거.
GitHub 버튼과 프로젝트 추가(+) 버튼은 유지.

## 상태 보존

### 마지막 세션 기억

`AppState`에 `lastSessionPerProject: [UUID: UUID]` 추가:
- 프로젝트 전환 시 현재 프로젝트의 `currentSessionId`를 저장
- 다른 프로젝트로 전환 시 해당 프로젝트의 저장된 세션 ID로 자동 복귀
- 저장된 세션이 없으면 기존 동작 유지 (최신 세션 또는 빈 채팅)

### 스크롤 위치
이번 범위 제외. 세션 복귀 시 최하단 이동 (기존 동작 유지).

## 수정 파일

| 파일 | 변경 내용 |
|------|-----------|
| `AppState.swift` | `lastSessionPerProject: [UUID: UUID]` 추가, `selectProject()` 수정 |
| `ChatView.swift` | `toolbarArea` — 정적 텍스트 → 탭 컴포넌트 |
| `MainView.swift` | 사이드바 프로젝트 드롭다운 제거 |

## 리스크

| 리스크 | 대응 |
|--------|------|
| 탭이 많을 때 오버플로우 | `ScrollView(.horizontal)` 로 처리 |
| 사이드바 드롭다운 제거 후 탭이 유일한 전환 수단 | 탭이 항상 노출되므로 문제 없음 |
| `lastSessionPerProject` 저장된 세션이 삭제된 경우 | `sessions` 배열에서 해당 ID 유효성 확인 후 없으면 무시 |
