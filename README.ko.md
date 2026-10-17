<div align="center">

# QuotaBar

### AI 잔여 한도, 한눈에.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
여러 AI 서비스의 남은 사용 한도와 잔액을 Mac 메뉴 막대에 모아 보세요.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · **한국어** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

<img src="docs/images/quotabar-menubar.png" alt="원본 메뉴 막대는 유지하고 나머지 화면은 부드럽게 흐리게 처리한 QuotaBar 실제 사용 화면" width="530">

**사용량 페이지는 덜 열고, 하던 일에 더 집중하세요.**

</div>

코드를 쓰고, 모델을 바꾸고, 작업을 실행하다 보면 궁금한 것은 간단합니다. 얼마나 더 쓸 수 있을까요? QuotaBar는 서비스 아이콘과 간결한 숫자로 남은 한도를 보여 주어, 여러 사용량 페이지를 찾아다니는 수고를 줄여 줍니다.

![원본 메뉴 막대는 유지하고 나머지 화면은 부드럽게 흐리게 처리한 QuotaBar 실제 사용 화면](docs/images/quotabar-desktop-privacy.png)

<sub>실제 사용 화면입니다. 맨 위 메뉴 막대는 원본을 유지했고, 나머지는 모자이크 없이 부드럽게 흐리게 처리했습니다. 숫자는 촬영 시점의 값이며 `--`는 읽을 수 있는 데이터가 없음을 뜻합니다.</sub>

## 남은 한도를 늘 보이는 곳에

- **여러 서비스 동시 표시**: Codex / GPT, Kimi, Cursor, DeepSeek를 각각 표시하거나 숨길 수 있습니다.
- **뜻이 분명한 숫자**: Codex는 조회된 한도 구간 중 가장 낮은 잔여 비율, Cursor는 선택한 Cursor Models / Other Models 한도, DeepSeek는 실제 가용 잔액을 표시합니다.
- **네이티브 글래스 UI**: AppKit, SwiftUI와 macOS 27의 유리 소재로 패널과 설정 화면을 구성했습니다.
- **로컬 사용 이력**: SQLite에 시간별로 기록하고 일·주·월·분기·년 단위 요약, 도넛 차트와 히트맵을 제공합니다.
- **확장 가능한 Swift 앱**: Swift Package Manager로 빌드하며 타사 런타임 의존성이 없습니다.

## 지원 현황과 수치의 의미

Codex / GPT는 로컬에서 로그인한 Codex 계정의 사용량이며, 일반 ChatGPT 메시지 한도가 아닙니다. Kimi는 공개 문서가 없는 멤버십 엔드포인트를 사용하므로 변경될 수 있습니다. Cursor는 로컬 로그인 상태를, DeepSeek는 공식 API Key를 사용합니다. ZCode는 아직 구현되지 않았습니다. Claude Code의 기존 계정 패널은 유지되지만 새 메뉴 막대의 개별 서비스 항목에는 포함되지 않습니다.

이력은 샘플 사이의 한도 변화를 퍼센트포인트로 표시합니다. 토큰 수, 청구 금액 또는 작업 시간이 아닙니다. DeepSeek 잔액은 아직 통합 소모량 차트에 포함되지 않습니다.

## 시작하기

**macOS 27 이상, Xcode 27.x / Swift 6.4**가 필요합니다. 현재 소스 코드를 제공하며 이 커스텀 버전의 GitHub 설치 패키지는 아직 없습니다. 실행 후 메뉴 막대에서 설정을 열고 서비스와 본인 계정을 구성하세요.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## 개인정보와 인증 정보

사용 가능한 계정이나 키는 포함하지 않습니다. Kimi 토큰과 직접 저장한 DeepSeek Key는 로컬 `~/Library/Application Support/QuotaBar/credentials.json`에 보관됩니다. 파일 권한은 `0600`, 디렉터리 권한은 `0700`인 권한 보호 평문 파일입니다. 기존 다중 계정 인증 정보는 macOS Keychain을 사용합니다. 조회에 필요한 인증 정보는 해당 서비스에 전송됩니다.

[개발 가이드](CONTRIBUTING.md) · [보안](SECURITY.md) · [개발 과정](docs/ORIGINS.md) · [라이선스 전문](LICENSE)

## 개발 과정과 코드 출처

이 프로젝트는 MyKWK가 2026년 8월부터 사용하던 로컬 Kimi 한도 도구에서 시작했습니다. 9월 16일 여러 서비스 지원을 개발하면서 Chiloh / chilohwei가 관리하는 별개의 동명 프로젝트 QuotaBar 코드를 도입하고, 우리가 만든 Kimi 기능과 제품 설계, 후속 확장 기능을 통합했습니다. 이 버전은 MyKWK가 관리합니다.

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

사용한 외부 코드의 저작권 표시와 사용자 정의 라이선스를 유지합니다. 개인·교육·연구 등 비상업적 이용은 원래 라이선스에 따르며, 상업적 이용에는 원저작자의 사전 서면 허가가 필요합니다. 업스트림 프로젝트나 각 서비스 제공자의 공식 승인 또는 보증을 뜻하지 않습니다.

---

사용량 페이지를 여는 횟수가 줄었다면 Star와 피드백으로 함께해 주세요.
