# USMCA Origin Compliance Management System — UI Design Specification

**USMCA 원산지 증명 관리 시스템 (UOCM)** · 설계 문서 리포지토리

Tier-1 자동차 부품 공급사(현대 · 기아 · MOBIS 납품)의 USMCA 원산지 증명/컴플라이언스
관리 시스템 UI 설계서입니다. PPT 제안서(`USMCA_Origin_Compliance_Proposal`)의
5대 기능 영역을 L1(시스템) → L2(모듈) → L3(화면 상세) 3단계로 전개합니다.

## 문서 구조

| VOL | 코드 | 모듈 | Phase | 파일 |
|-----|------|------|-------|------|
| — | — | **Index** (시스템 개요) | — | `INDEX.html` |
| 01 | — | Overview · 범위 · 로드맵 · 기술스택 | — | `VOL01_Overview.html` |
| 02 | **DOC** | Document Management · 증빙문서관리 | P1 | `VOL02_DOC_Document_Management.html` |
| 03 | **LBL** | Label Management · 라벨관리 | P2 | `VOL03_LBL_Label_Management.html` |
| 04 | **ORG** | Origin Management · 원산지관리 | P3 | `VOL04_ORG_Origin_Management.html` |
| 05 | **AUD** | Audit Support · 감사대응 | P1~ | `VOL05_AUD_Audit_Support.html` |
| 06 | **INT** | Integration · 시스템연계 | P4 | `VOL06_INT_Integration.html` |
| 07 | **SYS** | System / Admin · 시스템관리 | P1 | `VOL07_SYS_System.html` |
| 08 | **MD** | Master Data · 기준정보 | P1 | `VOL08_MD_Master_Data.html` |

## 설계 레벨 (3-Tier)

- **L1 — INDEX** : 시스템 전체 개요 · 모듈 맵 · 통계 · 로드맵
- **L2 — 모듈 허브** (`VOL0X_XXX.html`) : 모듈별 화면 흐름 · KPI · 화면 카드 · 업무규칙(BR)
- **L3 — 화면 상세** (`VOL0X_XXNN_*.html`) : 화면별 7섹션 상세 설계
  1. Overview 개요 · 2. Screen Mockup 목업(Web/PDA) · 3. UI Component Spec 컴포넌트 명세
  4. Event & Action Flow 이벤트 흐름 · 5. Exception Handling 예외 처리
  6. Linked Screens 연계 화면 · 7. Business Rules 업무 규칙

## 보기

각 `.html` 파일을 브라우저로 직접 엽니다. `INDEX.html` 이 진입점입니다.
