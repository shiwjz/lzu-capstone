
# 오디가 (ODIGA)

### 자연어 검색과 혼잡도 정보를 활용한 맞춤형 장소·코스 추천 서비스

> 본 문서는 로컬 실행 환경을 기준으로 작성되었습니다. 외부 배포 URL은 제공하지 않습니다.

---

## 01. 프로젝트 개요

### 프로젝트 주제
**자연어 기반 맞춤형 장소·코스 추천 및 혼잡도 분석 서비스**

오디가(ODIGA)는 사용자가 원하는 지역, 시간, 동행 형태, 분위기 등을 자연어로 입력하면 검색 조건을 분석하고, 적합한 장소와 방문 코스를 추천하는 서비스입니다.

단순한 장소 검색을 넘어 장소별 혼잡도, 음식 취향, 활동 유형, 방문 순서 등을 함께 고려하여 사용자에게 맞춤형 코스를 제공합니다.

**예시 검색**

> 토요일 오후 3시 성수에서 카페 말고 놀자

### 프로젝트 핵심 흐름

```text
자연어 검색
    ↓
검색 조건 추출
    ↓
장소 후보 선정
    ↓
혼잡도 및 취향 반영
    ↓
맞춤형 코스 생성
    ↓
코스 확인 · 수정 · 공유
```

---

## 02. 문제 정의

사용자가 약속 장소를 결정할 때는 단순히 어디로 갈지를 넘어 다음과 같은 요소를 함께 고려해야 합니다.

- 방문할 지역과 시간
- 함께하는 사람의 취향
- 장소의 혼잡도
- 음식 및 활동 유형
- 장소 간 이동 순서와 체류 시간

기존 장소 검색 방식에서는 사용자가 여러 장소를 직접 비교하고 방문 일정을 구성해야 하는 불편함이 있습니다.

본 프로젝트는 자연어 처리와 장소 추천 기술을 활용하여 이러한 문제를 해결하고자 합니다.

### 주요 연구 질문

| 구분 | 연구 질문 |
|---|---|
| Q1 | 자연어 검색 문장에서 지역, 시간, 취향 등을 추출할 수 있는가? |
| Q2 | 태그 및 혼잡도 데이터를 활용하여 적합한 장소를 추천할 수 있는가? |
| Q3 | 장소의 방문 순서와 체류 시간을 반영한 코스를 생성할 수 있는가? |
| Q4 | 사용자가 추천 코스를 수정하고 공유할 수 있는가? |

---

## 03. 주요 기능

| 기능 | 설명 |
|---|---|
| 자연어 검색 | 사용자의 문장을 분석하여 검색 조건 추출 |
| AI 기반 조건 추출 | Gemini API를 사용하여 지역, 시간, 분위기 등 추출 |
| 규칙 기반 대체 처리 | Gemini API 사용이 불가능할 경우 규칙 기반 추출 |
| 맞춤형 코스 추천 | 사용자 조건에 따라 장소 및 방문 코스 생성 |
| 코스 유형 선택 | 기본, 술, 문화, 산책, 쇼핑 등 유형 지원 |
| 장소 제외 및 추가 | 특정 장소 종류를 제외하거나 추가 |
| 방문 순서 변경 | 사용자가 직접 코스 순서 수정 |
| 장소 킵 기능 | 원하는 장소를 고정하여 추천에 반영 |
| 혼잡도 정보 | 시간대별 및 요일별 혼잡도 활용 |
| 장소 상세 정보 | 장소 및 혼잡도 정보 확인 |
| 코스 수정 및 공유 | 추천 코스를 변경하고 공유 |
| 회원 및 개인 설정 | 사용자 계정과 선호 정보 관리 |
| 장소 사진 | Google Places API 기반 사진 조회 기능 |

일부 기능은 데이터베이스 연결이나 외부 API 설정에 따라 사용이 제한될 수 있습니다.

상세 API 요청 및 응답 형식은 [API 명세서](docs/api-spec.md)를 참고합니다.

---

## 04. 기술 스택

| 구분 | 사용 기술 |
|---|---|
| Frontend | Flutter, Dart, Flutter Web |
| Backend | Java 21, Spring Boot 4.1.1 |
| Build Tool | Gradle |
| Database | MySQL, Aiven MySQL |
| ORM | Spring Data JPA, Hibernate |
| 자연어 처리 | Gemini API |
| 대체 조건 추출 | Rule-based Processing |
| 장소 사진 | Google Places API |
| 개발 도구 | IntelliJ IDEA, VS Code, Android Studio |
| 버전 관리 | Git, GitHub |
| 실행 환경 | Localhost, Chrome, Bash |

---

## 05. 프로젝트 폴더 구조

```text
lzu-capstone/
│
├── capstone-backend/
│   ├── src/
│   │   └── main/
│   │       ├── java/
│   │       └── resources/
│   ├── build.gradle
│   ├── gradlew
│   └── gradlew.bat
│
├── capstone_odiga/
│   ├── lib/
│   │   ├── api/
│   │   ├── screens/
│   │   ├── state/
│   │   ├── widgets/
│   │   └── main.dart
│   ├── assets/
│   ├── web/
│   └── pubspec.yaml
│
├── database/
│   ├── erd/
│   ├── schema/
│   └── validation/
│
├── blog_tag/
│
├── docs/
│   └── api-spec.md
│
├── .gitignore
└── Readme.md
```

### 주요 디렉터리 설명

| 디렉터리 | 역할 |
|---|---|
| capstone-backend | Spring Boot 서버 및 API |
| capstone_odiga | Flutter 기반 사용자 화면 |
| database/erd | 데이터베이스 ERD 설계 파일 |
| database/schema | 테이블 생성 SQL |
| database/validation | 데이터베이스 구조 검증 |
| blog_tag | 장소 관련 블로그 태그 처리 |
| docs | API 명세 및 프로젝트 문서 |

`run_local.sh`, `.env.example`은 로컬 실행 환경 구성을 위해 추가할 예정인 파일입니다.

---

## 06. 개발 환경 설치

본 프로젝트는 Java 21과 Flutter를 기반으로 실행됩니다.

처음 프로젝트를 실행하는 사용자도 동일한 환경을 구성할 수 있도록 설치 순서를 안내합니다.

### 6-1. Git 설치

Git은 프로젝트 코드를 다운로드하고 버전을 관리하는 도구입니다.

1. [Git 공식 사이트](https://git-scm.com/downloads)에 접속합니다.
2. 운영체제에 맞는 Git을 다운로드합니다.
3. 설치 후 터미널에서 다음 명령어를 입력합니다.

```bash
git --version
```

Git 버전이 표시되면 정상적으로 설치된 것입니다.

### 6-2. 프로젝트 다운로드

터미널에서 다음 명령어를 실행합니다.

```bash
git clone https://github.com/shiwjz/lzu-capstone.git
```

프로젝트 폴더로 이동합니다.

```bash
cd lzu-capstone
```

### 6-3. Java 21 설치

백엔드 서버는 Java 21을 사용합니다.

1. [Adoptium JDK 21](https://adoptium.net/temurin/releases/?version=21)에 접속합니다.
2. 운영체제에 맞는 JDK 21을 설치합니다.
3. 필요한 경우 `JAVA_HOME`과 PATH 환경변수를 설정합니다.
4. 터미널에서 설치 여부를 확인합니다.

```bash
java -version
```

출력 결과에서 Java 버전이 21인지 확인합니다.

본 프로젝트는 Gradle Wrapper를 포함하고 있으므로 Gradle을 별도로 설치할 필요가 없습니다.

### 6-4. Flutter 설치

Flutter는 사용자 화면을 구현한 프레임워크입니다.

1. [Flutter 공식 설치 문서](https://docs.flutter.dev/install)에 접속합니다.
2. 운영체제에 맞는 Flutter SDK를 설치합니다.
3. Flutter SDK의 `bin` 경로를 PATH에 추가합니다.
4. 터미널에서 설치 여부를 확인합니다.

```bash
flutter --version
```

개발 환경을 점검합니다.

```bash
flutter doctor
```

사용 가능한 기기를 확인합니다.

```bash
flutter devices
```

Chrome이 표시되면 Flutter Web을 실행할 수 있습니다.

본 프로젝트는 Chrome 브라우저를 이용하여 시연하므로 Android 에뮬레이터는 필수가 아닙니다.

### 6-5. Bash 실행 환경

`run_local.sh`는 Bash 스크립트입니다.

- Windows: Git Bash 또는 WSL
- macOS: Terminal
- Linux: Terminal

Windows 사용자는 Git Bash를 이용하여 실행하는 것을 권장합니다.

---

## 07. 환경변수 설정

API 키와 데이터베이스 접속 정보는 코드에 직접 작성하지 않고 환경변수로 관리합니다.

### 7-1. .env.example 파일

프로젝트 루트에 `.env.example` 파일을 생성합니다.

```dotenv
GEMINI_API_KEY=
GOOGLE_PLACES_API_KEY=
ODIGA_DATA_DIR=
DB_URL=
DB_USERNAME=
DB_PASSWORD=
JWT_SECRET=
```

`.env.example`에는 환경변수 이름만 작성하며 실제 API 키와 비밀번호를 포함하지 않습니다.

### 7-2. .env 파일 생성

`.env.example`을 복사하여 `.env` 파일을 생성합니다.

```bash
cp .env.example .env
```

생성한 `.env` 파일에는 자신의 개발 환경에 맞는 값을 입력합니다.

### 환경변수 설명

| 환경변수 | 용도 |
|---|---|
| GEMINI_API_KEY | Gemini 기반 자연어 조건 추출 |
| GOOGLE_PLACES_API_KEY | Google Places API 연동 |
| ODIGA_DATA_DIR | 로컬 혼잡도 및 관련 데이터 저장 경로 |
| DB_URL | MySQL 접속 주소 |
| DB_USERNAME | 데이터베이스 사용자명 |
| DB_PASSWORD | 데이터베이스 비밀번호 |
| JWT_SECRET | 사용자 인증 토큰 서명 키 |

### 7-3. API 키 보안

실제 API 키와 비밀번호는 GitHub에 업로드하지 않습니다.

`.gitignore`에 다음 항목을 등록합니다.

```gitignore
.env
```

현재 저장소에는 `.env` 제외 설정이 포함되어 있습니다.

**주의:** Spring Boot는 프로젝트 루트의 `.env` 파일을 자동으로 읽지 않습니다. 실행 전에 환경변수로 전달하거나 통합 실행 스크립트에서 불러와야 합니다.

---

## 08. 로컬 실행 방법

본 프로젝트는 외부 배포 서버 대신 로컬 환경에서 실행하는 것을 기준으로 합니다.

### 8-1. 통합 실행 스크립트

최종적으로 `run_local.sh` 하나로 백엔드 서버와 Flutter 앱이 실행되도록 구성하는 것을 목표로 합니다.

```bash
bash run_local.sh
```

### 통합 실행 목표

1. `.env` 파일에서 환경변수를 읽습니다.
2. Spring Boot 백엔드 서버를 실행합니다.
3. 서버 연결 상태를 확인합니다.
4. Flutter 패키지 의존성을 설치합니다.
5. Flutter Web을 Chrome에서 실행합니다.
6. 로컬 백엔드 API에 연결합니다.

**현재 저장소에는 `run_local.sh`가 확인되지 않아 구현 및 동작 검증이 필요합니다.**

### 8-2. 백엔드 서버 직접 실행

프로젝트 루트에서 다음 명령어를 실행합니다.

```bash
cd capstone-backend
```

macOS 또는 Linux:

```bash
./gradlew bootRun
```

Windows PowerShell:

```powershell
.\gradlew.bat bootRun
```

Windows Git Bash:

```bash
./gradlew bootRun
```

서버가 정상적으로 실행되면 다음 로컬 주소에서 테스트할 수 있습니다.

```text
http://localhost:8080/api/test
```

백엔드의 기본 포트는 `8080`입니다.

실행 전에 필요한 환경변수가 설정되어 있어야 합니다.

### 8-3. Flutter 앱 직접 실행

새로운 터미널을 열어 다음 명령어를 실행합니다.

```bash
cd capstone_odiga
```

패키지 의존성을 설치합니다.

```bash
flutter pub get
```

Chrome에서 Flutter 앱을 실행합니다.

```bash
flutter run -d chrome --dart-define=ODIGA_API=http://localhost:8080
```

해당 명령어는 Flutter 앱이 로컬 Spring Boot 서버에 연결되도록 설정합니다.

### 8-4. Mock API 주의사항

Flutter 앱은 `ODIGA_API` 값을 기준으로 실제 API와 Mock API를 구분합니다.

| 실행 방식 | 결과 |
|---|---|
| ODIGA_API 지정 | 실제 HTTP 백엔드 사용 |
| ODIGA_API 미지정 | Mock API 사용 |

실제 서버와 연결하여 시연할 경우 반드시 다음 옵션을 포함합니다.

```bash
--dart-define=ODIGA_API=http://localhost:8080
```

---

## 09. 데이터베이스 설계

### 9-1. 데이터베이스 개요

본 프로젝트는 MySQL을 사용하여 사용자 정보, 장소 정보, 코스 정보 등을 관리합니다.

데이터베이스 설계는 ERD를 기반으로 진행하며, 저장소에는 ERD v1부터 v3까지의 설계 파일이 포함되어 있습니다.

```text
database/
├── erd/
├── schema/
└── validation/
```

### 9-2. ERD v3

최종 데이터베이스 구조는 ERD v3를 기준으로 정리하는 것을 목표로 합니다.

주요 관리 대상은 다음과 같습니다.

| 데이터 | 설명 |
|---|---|
| 사용자 | 사용자 계정 및 인증 정보 |
| 사용자 선호 | 지역, 분위기 등 개인 설정 |
| 장소 | 장소 이름, 위치, 카테고리 등 |
| 장소 태그 | 장소별 분위기와 관련 키워드 |
| 코스 | 추천 코스 및 관련 조건 |
| 코스 장소 | 코스에 포함된 장소와 방문 순서 |
| 코스 공유 | 코스 공유 정보 |
| 저장 정보 | 사용자가 저장한 장소 및 코스 |
| 혼잡도 | 지역 및 시간대별 혼잡도 관련 데이터 |

### 9-3. SQL 정리

ERD v3를 기준으로 다음 항목을 점검합니다.

1. 테이블 이름 및 컬럼 일치 여부
2. 기본키(PK)와 외래키(FK) 설정
3. 테이블 간 관계
4. 컬럼 자료형
5. UNIQUE 및 NOT NULL 제약 조건
6. 테이블 생성 순서
7. JPA 엔티티와 실제 SQL 구조

현재 저장소의 일부 SQL은 이전 ERD 구조를 사용하므로 최종 v3 적용 전 검증이 필요합니다.

### 9-4. Aiven MySQL 연결

원격 데이터베이스를 사용하는 경우 Aiven MySQL에 연결합니다.

시연 노트북에서 다음 사항을 확인합니다.

- Aiven 데이터베이스 서비스 상태
- MySQL 호스트 및 포트
- 사용자명과 비밀번호
- SSL/TLS 연결 설정
- 데이터베이스 접근 가능 여부

MySQL 클라이언트를 통해 접속을 확인할 수 있습니다.

```bash
mysql --host=<AIVEN_HOST> --port=<AIVEN_PORT> --user=<DB_USER> --password --ssl-mode=REQUIRED
```

실제 접속 정보는 `.env` 또는 별도의 안전한 설정 방식으로 관리합니다.

### 9-5. 로컬 MySQL 사용

Aiven에 연결할 수 없는 경우 로컬 MySQL을 대체 환경으로 사용할 수 있습니다.

MySQL을 설치하고 다음 데이터베이스를 생성합니다.

```sql
CREATE DATABASE IF NOT EXISTS capstone_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;
```

`.env` 파일에서 데이터베이스 연결 정보를 수정합니다.

```dotenv
DB_URL=jdbc:mysql://localhost:3306/capstone_db?serverTimezone=Asia/Seoul
DB_USERNAME=root
DB_PASSWORD=
```

비밀번호는 실제 로컬 MySQL 계정 설정에 맞게 입력합니다.

이후 ERD v3에 맞게 검증된 SQL을 적용해야 합니다.

---

## 10. 데이터베이스 백업 및 복구

데이터 손실을 방지하기 위해 데이터베이스 백업을 진행합니다.

### 10-1. 백업

MySQL의 `mysqldump`를 사용하여 데이터베이스를 백업할 수 있습니다.

```bash
mysqldump --user=root --password --single-transaction --databases capstone_db > capstone_db_backup.sql
```

백업 파일에는 테이블 구조와 데이터가 저장됩니다.

원격 MySQL을 백업할 경우 호스트 및 포트 정보를 추가합니다.

### 10-2. 복구

백업 파일을 이용하여 데이터베이스를 복구할 수 있습니다.

```bash
mysql --user=root --password < capstone_db_backup.sql
```

복구 전에 대상 데이터베이스와 백업 파일을 확인해야 합니다.

백업 파일에는 개인정보가 포함될 수 있으므로 공개 GitHub 저장소에 업로드하지 않습니다.

---

## 11. API 구조

백엔드는 REST API를 통해 Flutter 클라이언트와 통신합니다.

| Method | Endpoint | 설명 |
|---|---|---|
| GET | /api/test | 서버 상태 확인 |
| GET | /api/search?q=... | 브라우저 검색 테스트 |
| POST | /api/search | 자연어 검색 및 코스 추천 |
| PUT | /api/courses/{courseId} | 코스 수정 |
| POST | /api/courses/{courseId}/share | 코스 공유 생성 |
| GET | /api/share/{shareCode} | 공유된 코스 조회 |
| GET | /api/places/{placeId}/photos | 장소 사진 조회 |

상세 명세는 [`docs/api-spec.md`](docs/api-spec.md)를 참고합니다.

---

## 12. 프로젝트 시연 방법

### 12-1. 시연 환경 준비

시연 전 다음 사항을 확인합니다.

- Java 21 설치 확인
- Flutter 설치 확인
- Chrome 설치 확인
- `.env` 설정 확인
- MySQL 접속 상태 확인
- 백엔드 서버 실행 확인
- Flutter와 실제 API 연결 확인

### 12-2. 시연 진행 순서

**Step 1. 서버 실행**

Spring Boot 서버를 로컬에서 실행합니다.

**Step 2. Flutter 앱 실행**

Flutter Web을 Chrome에서 실행합니다.

**Step 3. 자연어 검색**

사용자가 원하는 장소와 활동을 자연어로 입력합니다.

예시:

> 토요일 오후 3시 성수에서 카페 말고 놀자

**Step 4. 검색 조건 확인**

입력 문장에서 추출된 지역, 날짜, 시간, 취향 등의 조건을 확인합니다.

**Step 5. 추천 코스 확인**

사용자 조건을 반영하여 생성된 추천 코스를 확인합니다.

**Step 6. 코스 수정**

장소 추가, 제외, 방문 순서 변경 등 사용자 지정 기능을 확인합니다.

**Step 7. 혼잡도 및 장소 정보 확인**

시간대별 혼잡도와 장소 상세 정보를 확인합니다.

**Step 8. 코스 저장 및 공유**

DB 연결과 관련 API가 정상적으로 작동하는 경우 저장 및 공유 기능을 시연합니다.

---

## 13. 오류 및 문제 해결

| 문제 | 해결 방법 |
|---|---|
| Java 실행 불가 | JDK 21 설치 및 PATH 확인 |
| Flutter 명령어 실행 불가 | Flutter SDK PATH 설정 확인 |
| Chrome 기기 인식 실패 | Chrome 설치 및 flutter doctor 확인 |
| 서버 연결 실패 | Spring Boot 서버 실행 및 8080 포트 확인 |
| Mock 데이터 출력 | ODIGA_API 옵션 설정 확인 |
| Gemini API 미작동 | API 키 및 서버 로그 확인 |
| 장소 사진 출력 실패 | Google Places API 키 및 권한 확인 |
| MySQL 연결 실패 | DB 접속 주소와 계정 정보 확인 |
| Aiven 연결 불가 | 서비스 상태, 네트워크 및 SSL 설정 확인 |
| SQL 오류 | ERD v3와 테이블 구조 비교 |
| 통합 스크립트 실행 불가 | run_local.sh 생성 및 Bash 환경 확인 |

---

## 14. 한계 및 향후 개선점

본 프로젝트는 자연어 기반 추천과 혼잡도 분석을 결합한 서비스이지만 몇 가지 개선 과제가 존재합니다.

첫째, 장소별 혼잡도 데이터의 정확도는 사용 가능한 데이터의 범위와 갱신 주기에 영향을 받습니다.

둘째, 장소의 실제 영업시간이 충분히 확보되지 않은 경우 기본 시간 규칙을 적용할 수 있습니다.

셋째, Gemini 및 Google Places API는 외부 서비스이기 때문에 네트워크와 API 사용량에 따라 기능이 제한될 수 있습니다.

넷째, 데이터베이스 ERD v3와 SQL 스크립트 및 JPA 엔티티의 일치 여부를 검증해야 합니다.

다섯째, 시연 환경에서 Aiven 연결이 불가능한 상황에 대비하여 로컬 MySQL 실행과 복구 절차를 마련해야 합니다.

마지막으로 `run_local.sh`를 구현하여 초보자도 별도의 복잡한 설정 없이 로컬 서버와 Flutter 앱을 실행할 수 있도록 개선할 예정입니다.

---

## 15. 참고 자료

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Spring Boot 공식 문서](https://docs.spring.io/spring-boot/index.html)
- [Java 21 다운로드](https://adoptium.net/temurin/releases/?version=21)
- [MySQL 공식 문서](https://dev.mysql.com/doc/)
- [Git 공식 문서](https://git-scm.com/doc)
- [프로젝트 API 명세](docs/api-spec.md)

---

### 프로젝트 실행 환경 안내

본 프로젝트는 **로컬 실행을 기준**으로 구성됩니다.

외부 배포 서버 없이 Java 21, Spring Boot, Flutter, MySQL을 이용하여 실행하는 것을 목표로 합니다.

현재 통합 실행 스크립트와 ERD v3 SQL 정리 및 데이터베이스 연결은 최종 검증이 필요한 상태입니다.
