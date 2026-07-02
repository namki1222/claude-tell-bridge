# tell-tmux

**Session-to-session messaging bridge for Claude Code over tmux.**
장수명 Claude Code 세션들(tmux 패널)이 상관키(KEY) 기반으로 서로 요청·응답을 주고받게 하는 초경량 브릿지.
데몬 없음 · DB 없음 · MCP 없음 — **bash 스크립트 1개 + CLAUDE.md 규약**이 전부.

```
┌─ tmux (한 화면 = 한 팀) ────────────────────────────────────────┐
│ [proj-a:server]                     [proj-a:web]               │
│  FastAPI 담당 Claude                 React 담당 Claude          │
│     │ tell proj-a web "응답에 pagination 메타 추가했어.          │
│     │  GET /orders 스키마 바뀜 — 프론트 반영해줘" ──► KEY=a1b2c3 │
│     ◄── tell -r a1b2c3 proj-a server "반영 완료: ..." ──────────│
└────────────────────────────────────────────────────────────────┘
```

**핵심은 백엔드 ↔ 프론트엔드 세션끼리의 직접 대화다.** 각 세션은 자기 코드베이스 전체를 아는 상태로 질문에 답한다 — API 계약 협상, "너네 nginx 어떻게 세팅했어?", 스키마 변경 전파를 **그 도메인의 주인이 직접** 처리한다.

## 왜?

- **컨텍스트 주인에게 물어본다** — 신선한 에이전트가 추측하는 게 아니라, 그 프로젝트에 *상주*하는 세션이 자기 코드·환경을 직접 확인하고 답한다.
- **장수명 컨텍스트** — 각 패널은 프로젝트 이력·메모리·CLAUDE.md를 계속 유지. 매번 재설명(온보딩) 비용이 없다.
- **화면 분할 = 팀 관제탑** — `tell ws` 한 번으로 역할별 패널 배치가 재현된다. 모든 AI 동료가 일하는 걸 한 화면에서 보면서, 아무 패널이나 클릭해 직접 지시할 수 있다.
- **비동기 논블로킹** — 6자리 상관키로 여러 요청 동시 추적. 보낸 쪽은 기다리지 않는다.
- **유리箱 오케스트레이션** — 모든 대화가 tmux 화면에 그대로 보인다. 블랙박스 없음, 언제든 사람이 개입.
- **인프라 제로** — `tmux send-keys`로 상대 입력창에 직접 타이핑하는 게 전부. 데몬·큐·MCP 서버 없음.

## 권장 패턴: 허브(비서) 세션

세션 간 P2P 대화가 코어지만, 프로젝트가 여럿이면 **허브 세션 하나**를 두는 걸 권장한다:

```
        사용자 (로컬 or 폰 Remote Control)
                    │
                [hub:hub]  ← 라우팅·위임·취합·보고만 담당
              ┌─────┼─────────┐
        [proj-a:*]  [proj-b:*]  [proj-c:*]
```

- 허브가 요청을 적절한 세션:역할로 라우팅하고 KEY별로 취합해 보고
- 폰(Remote Control)에서 허브 하나만 잡으면 **전 프로젝트 원격 지휘**
- `tell init`이 허브용 CLAUDE.md 규약을 자동 생성해준다

## 설치

```bash
npm install -g tell-tmux
tell doctor        # 환경 점검 (tmux, claude CLI)
```

요구사항: tmux · [Claude Code](https://claude.com/claude-code) CLI · macOS/Linux

## 시작하기

### A. 처음부터 (신규)
```bash
tell init          # 마법사: 허브 + 프로젝트 세션/역할/디렉터리 등록
                   #        각 프로젝트 CLAUDE.md에 협업 규약 자동 삽입
tell ws hub        # 허브 세션 띄우기
tell ws proj-a     # 프로젝트 세션 띄우기 (패널별 claude 자동 실행)
```

### B. 이미 tmux에서 Claude Code 쓰는 중 (편입 — 재시작 불필요)
```bash
tell adopt         # 떠 있는 패널 스캔 → 역할 이름 지정 → CLAUDE.md 규약 삽입
                   # → 떠 있는 Claude에 "규약 읽어+핑퐁" 메시지 자동 전송
```
기존 대화 컨텍스트를 유지한 채 그대로 브릿지에 편입된다.
(tmux 밖에서 쓰던 세션은 tmux 패널에서 `claude --resume` 으로 이어받으면 됨)

## 사용법

```bash
# 요청 (KEY 자동 생성·출력)
tell proj-a server "결제 API에 환불 엔드포인트 추가해줘. 끝나면 받은 키로 응답해줘"
# → [tell] 요청 KEY=a1b2c3

# 응답 (받은 요청의 KEY 그대로) — 보통 Claude가 CLAUDE.md 규약에 따라 스스로 실행
tell -r a1b2c3 hub hub "완료: POST /refunds 추가, 테스트 통과"
```

메시지 헤더 프로토콜 (자동 부착):
```
[세션 요청 - a1b2c3 from hub/hub] 결제 API에 환불 엔드포인트 추가해줘...
[세션 응답 - a1b2c3 from proj-a/server] 완료: POST /refunds 추가...
```
- `from` = 발신자 자동 감지 → 받는 쪽이 어디로 `tell -r` 할지 안다
- 대상이 작업 중이어도 전송됨 (Claude Code가 입력을 큐잉 → 작업 끝나고 처리)
- 입력창에 사용자가 타이핑 중이면 10초 대기 후 재시도 (덮어쓰기 방지)

## 명령어

| 명령 | 설명 |
|---|---|
| `tell <세션> <역할> "<메시지>"` | 요청 전송 (KEY 생성) |
| `tell -r <KEY> <세션> <역할> "<메시지>"` | 응답 전송 |
| `tell ws [<세션>]` | 워크스페이스 부트스트랩/접속 (없으면 목록) |
| `tell init` | 신규 셋업 마법사 |
| `tell adopt` | 떠 있는 tmux 세션 편입 |
| `tell doctor` | 환경 점검 |

설정 파일: `~/.config/tell-tmux/workspaces.conf` — `세션|역할|디렉터리` 한 줄씩.

## 규약 (CLAUDE.md)

브릿지의 절반은 **규약**이다. `init`/`adopt`가 각 프로젝트 CLAUDE.md에 자동 삽입하는 핵심 규칙:

1. **응답 = `tell -r`을 Bash로 실제 실행** — 채팅에 텍스트만 쓰면 상대 세션은 못 본다
2. 회신 주소는 받은 헤더의 `from`에서 읽는다 (자기한테 보내면 루프)
3. `[세션 요청]`이 작업 중 오면 **현재 작업을 끝낸 뒤** 처리
4. 헤더 없는 메시지 = 사람 직접 입력 → 즉시 처리

템플릿: [`templates/CLAUDE-section-role.md`](templates/CLAUDE-section-role.md) · [`templates/CLAUDE-section-hub.md`](templates/CLAUDE-section-hub.md)

## ⚠️ 보안

- `send-keys` 기반 — **같은 tmux 서버에 접근 가능한 누구나 메시지를 주입할 수 있다.** 신뢰된 로컬 환경 전용.
- **비밀번호·토큰·시크릿을 절대 tell로 보내지 말 것** — 상대 패널 스크롤백/트랜스크립트에 평문으로 남는다.
- 상관키는 라우팅용이지 인증이 아니다.

## 알려진 제약

- 입력창 감지가 Claude Code의 프롬프트 렌더링(`❯`)을 읽는다 — CLI UI가 크게 바뀌면 점검 필요
- 헤더 프로토콜이 현재 한국어 (i18n 예정)
- tmux 세션 이름에 `=` 사용 불가, 역할 이름은 세션 내 유일해야 함

## English (TL;DR)

`tell-tmux` lets multiple long-lived Claude Code sessions (tmux panes) message each other with correlation keys, via `tmux send-keys` — no daemon, no MCP. `npm i -g tell-tmux`, then `tell init` (fresh) or `tell adopt` (existing sessions). Half the magic is a CLAUDE.md convention (auto-inserted) that tells each Claude to *actually run* `tell -r KEY <session> <role> "..."` to reply. Korean-first headers for now; PRs welcome.

## License

MIT
