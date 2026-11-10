오디가 (ODIGA)
자연어 검색과 혼잡도 정보를 활용한 맞춤형 장소·코스 추천 서비스

이 문서는 로컬 실행을 기준으로 작성했습니다. 외부 배포 URL은 제공하지 않습니다.

01. 프로젝트 개요
오디가는 사용자가 원하는 지역, 시간, 동행 형태, 분위기 등을 자연어로 입력하면 검색 조건을 분석하고 관련 장소와 방문 코스를 추천하는 서비스입니다. 장소별 혼잡도, 음식 취향, 활동 유형 등을 함께 고려하여 단순한 장소 검색을 넘어 이동 순서가 있는 코스를 제시합니다.

예시 검색: 토요일 오후 3시 성수에서 카페 말고 놀자

프로젝트의 핵심 흐름은 자연어 요청 → 조건 추출 → 장소 후보 선정 → 코스 생성 → 결과 확인·수정·공유입니다.
02. 문제 정의
사용자가 약속 장소를 정할 때에는 어디로 갈지뿐 아니라 언제 갈지, 얼마나 붐빌지, 함께하는 사람의 취향은 무엇인지 등을 동시에 고려해야 합니다. 검색 결과에서 여러 장소를 개별적으로 비교한 뒤 일정을 직접 구성해야 하는 부담을 줄이는 것이 본 프로젝트의 목표입니다.

주요 설계 질문은 다음과 같습니다.
구분	질문
Q1	일상적인 검색 문장을 지역·시간·장소 유형·취향 등의 구조화된 조건으로 변환할 수 있는가?
Q2	태그·혼잡도 정보를 활용하여 요청에 맞는 장소 후보를 선정할 수 있는가?
Q3	장소의 방문 순서와 체류 시간을 반영한 코스를 생성할 수 있는가?
Q4	사용자가 제안된 코스를 수정하고 공유할 수 있는가?


03. 주요 기능
기능	설명
자연어 검색	Gemini 기반 조건 추출, API 키가 없거나 요청에 실패하면 규칙 기반 추출로 전환
맞춤형 코스 추천	지역·날짜·시간·분위기·장소 종류를 반영하여 코스 구성
코스 유형 선택	기본, 술, 문화, 산책, 쇼핑 등 코스 유형 지원
사용자 지정	장소 종류 제외·추가, 방문 순서 조정, 일부 장소 고정(킵)
장소 및 혼잡도	장소 정보와 시간대별·요일별 혼잡도 정보를 활용
코스 수정·공유	코스 변경 API와 공유 API 제공
회원·개인 설정	계정 및 개인 선호 정보 관련 기능은 DB 연결이 필요하며 별도 검증 필요
장소 사진	Google Places API 연동 기능은 API 키·실행 환경에서 별도 확인 필요


실제 API 요청·응답 형식은 [`docs/api-spec.md`](docs/api-spec.md)를 참고합니다. 구현 상황과 실행 환경에 따라 일부 기능이 제한될 수 있습니다.
04. 기술 스택
구분	기술
프론트엔드	Flutter, Dart, Flutter Web
백엔드	Java 21, Spring Boot 4.1.1, Gradle
데이터베이스	MySQL, JPA/Hibernate, Aiven MySQL(선택)
자연어 처리	Gemini API, 규칙 기반 대체 처리
외부 서비스	Google Places API(장소 사진 등)
개발·실행	Git, Chrome, Bash, Android Studio 또는 VS Code(선택)


05. 프로젝트 폴더 구조
lzu-capstone/
├── capstone-backend/              # Java / Spring Boot 서버
│   ├── src/main/java/             # 서버 코드
│   ├── src/main/resources/        # 설정 및 내장 데이터
│   ├── build.gradle
│   ├── gradlew
│   └── gradlew.bat
├── capstone_odiga/                # Flutter 클라이언트
│   ├── lib/
│   │   ├── api/                  # HTTP/Mock API 연결
│   │   ├── screens/              # 화면
│   │   ├── state/                # 상태 관리
│   │   ├── widgets/              # 공통 UI
│   │   └── main.dart
│   ├── assets/
│   ├── web/
│   └── pubspec.yaml
├── database/
│   ├── erd/                      # ERD v1~v3
│   ├── schema/                   # SQL 스크립트 (v3 일치 여부 확인 필요)
│   └── validation/               # DB 검증 SQL
├── blog_tag/                     # 블로그 데이터 태그 처리
├── docs/api-spec.md              # API 명세
├── .gitignore
└── Readme.md
아래의 run_local.sh, .env.example, .env는 로컬 실행을 위한 목표 파일입니다. 기존 저장소에서 스크립트와 .env.example 존재가 확인되지는 않았으며, 아래 안내에 따라 추가·검증해야 합니다.

06. 처음 실행하는 사람을 위한 설치 가이드
6-1. Git 설치
Git 다운로드에서 운영체제에 맞는 Git을 설치합니다. 터미널에서 다음 명령으로 설치 여부를 확인합니다.
git --version
프로젝트를 내려받습니다.
git clone https://github.com/shiwjz/lzu-capstone.git
cd lzu-capstone
6-2. Java 21 설치
Adoptium Temurin 21에서 JDK 21을 설치합니다. Windows에서는 설치 시 JAVA_HOME 설정 옵션을 사용하거나 환경 변수에 직접 등록합니다.
java -version
출력된 Java 버전이 21인지 확인합니다. 서버 빌드에는 저장소에 포함된 Gradle Wrapper를 사용하므로 Gradle을 별도로 설치할 필요가 없습니다.
6-3. Flutter 설치
Flutter 공식 설치 가이드에서 운영체제에 맞는 Flutter SDK를 설치하고, flutter/bin을 PATH에 등록합니다. Chrome도 설치합니다.
flutter --version
flutter doctor
flutter devices
flutter devices에서 Chrome이 보이는지 확인합니다. Chrome이 목록에 없다면 Chrome 설치 및 Flutter PATH 설정을 다시 확인합니다. Android 앱을 별도로 실행하려는 경우 Android Studio 및 Android SDK 설치가 필요하지만, Chrome 시연만 할 경우 Android 에뮬레이터는 필수가 아닙니다.
6-4. Bash 실행 환경
run_local.sh는 Bash 스크립트이므로 macOS/Linux에서는 터미널에서, Windows에서는 Git Bash 또는 WSL에서 실행합니다. PowerShell에서 .sh 파일이 직접 실행되지 않을 수 있습니다.
07. 환경변수 설정
서버 API 키와 로컬 데이터 경로는 코드에 직접 기록하지 않고 프로젝트 루트의 .env로 관리합니다.
7-1. .env.example 예시
GEMINI_API_KEY=
GOOGLE_PLACES_API_KEY=
ODIGA_DATA_DIR=
DB_URL=
DB_USERNAME=
DB_PASSWORD=
JWT_SECRET=
.env.example에는 변수 이름과 빈 값만 기록합니다. 실제 값, 내부 접속 정보, 비밀번호는 넣지 않습니다.
7-2. .env 만들기
cp .env.example .env
Windows에서는 파일 탐색기 또는 편집기에서 .env.example을 복사하여 .env라는 이름으로 저장해도 됩니다. .env에 실제로 사용할 값을 입력합니다. ODIGA_DATA_DIR은 선택 사항으로, 로컬 혼잡도·성연령 데이터 디렉터리가 있을 때만 지정합니다.
변수	목적
GEMINI_API_KEY	자연어 조건 추출 및 제목 생성
GOOGLE_PLACES_API_KEY	Google Places 연동 기능
ODIGA_DATA_DIR	로컬 혼잡도/프로필 데이터 디렉터리
DB_URL	MySQL JDBC 연결 문자열
DB_USERNAME	DB 사용자명
DB_PASSWORD	DB 비밀번호
JWT_SECRET	로그인 토큰 서명용 비밀값


application.properties는 DB_URL, DB_USERNAME, DB_PASSWORD, ODIGA_DATA_DIR, JWT_SECRET 등을 읽습니다. Spring Boot가 프로젝트 루트의 .env를 자동으로 읽는 것은 아니므로, 실행 스크립트에서 환경변수로 전달해야 합니다.

.gitignore에는 다음 내용을 유지합니다.
.env
현재 저장소의 루트 .gitignore에는 이미 .env가 포함되어 있습니다. 중요한 원본 데이터, 인증키, DB 백업 파일은 Git에 커밋하지 않습니다.
08. 로컬 실행 가이드
8-1. 실행 전 준비
- Java 21, Flutter, Chrome, Bash 설치 확인
- 프로젝트 루트에 .env 생성
- DB를 사용할 경우 Aiven 또는 로컬 MySQL 접속 정보 설정
- run_local.sh 작성·실행 검증 완료 여부 확인
8-2. 통합 실행 (스크립트 구현 후)
프로젝트 루트에서 다음 명령을 실행하도록 구성합니다.
bash run_local.sh
스크립트 목표 동작
1. 프로젝트 루트의 .env를 읽어 환경변수로 내보냅니다.
2. capstone-backend에서 Spring Boot 서버를 시작합니다.
3. http://localhost:8080/api/test로 서버 응답을 확인합니다.
4. capstone_odiga에서 Flutter 의존성을 설치합니다.
5. flutter run -d chrome --dart-define=ODIGA_API=http://localhost:8080으로 Chrome 앱을 실행합니다.
6. 종료 시 백엔드 프로세스도 정리합니다.
현재 확인된 저장소에는 run_local.sh가 없습니다. 위 명령은 스크립트가 추가된 뒤에 사용합니다. README 작성만으로 통합 실행이 완성되지는 않습니다.

8-3. 스크립트 없이 각각 실행하기 (현재 저장소 기준)
터미널 1 — 서버 실행

macOS/Linux/Git Bash:
cd capstone-backend
./gradlew bootRun
Windows PowerShell:
cd capstone-backend
.\gradlew.bat bootRun
서버를 실행하기 전에 필요한 환경변수를 현재 터미널에 설정해야 합니다. .env를 만들기만 해서는 자동 적용되지 않습니다.

브라우저에서 http://localhost:8080/api/test로 응답을 확인합니다.

터미널 2 — Flutter 앱 실행
cd capstone_odiga
flutter pub get
flutter run -d chrome --dart-define=ODIGA_API=http://localhost:8080
ODIGA_API가 지정되어야 HTTP 백엔드에 연결됩니다. 이 값을 생략하면 코드상 Mock API가 사용되어 테스트용 JSON 결과가 보일 수 있습니다.
09. 데이터베이스: ERD v3 및 MySQL
9-1. 데이터베이스 구성
저장소의 database/erd/에는 ERD v1·v2·v3 파일이 있으며, database/schema/에는 테이블 생성 SQL이 있습니다.

주의: 일부 생성 SQL은 이전 ERD 구조를 반영하고 있습니다. 예를 들어 현재 06_create_course.sql은 course_id BIGINT AUTO_INCREMENT를 사용합니다. ERD v3를 기준으로 관계·컬럼·자료형을 맞추는 작업이 완료되기 전에는 이 SQL을 v3 최종본으로 간주하면 안 됩니다.

ERD 및 SQL 점검 사항:
1. ERD v3에 맞춘 테이블과 PK·FK·UNIQUE 제약 조건 확인
2. 테이블 생성 순서와 참조 테이블 존재 여부 확인
3. 사용자·장소·코스·공유·저장 기능에 필요한 스키마 확인
4. 실행 전후 스키마 검증 SQL 수행
5. 변경 전 백업과 복구 절차 확인
9-2. Aiven MySQL 사용
Aiven 콘솔에서 프로젝트의 MySQL 호스트·포트·데이터베이스명·사용자명·비밀번호를 확인합니다. 시연 노트북에서 Aiven 연결이 가능한지 먼저 확인합니다.

MySQL 클라이언트가 설치되어 있다면 다음과 같이 접속을 테스트할 수 있습니다.
mysql --host=<AIVEN_HOST> --port=<AIVEN_PORT> --user=<DB_USER> --password --ssl-mode=REQUIRED
접속 후 SHOW DATABASES; 등으로 접근 가능한 데이터베이스를 확인합니다. Aiven에서 제공하는 TLS/CA 설정이 추가로 필요한 환경에서는 해당 설정을 적용합니다.

Spring Boot의 DB_URL에는 jdbc:mysql://... 형태의 JDBC 연결 문자열을 사용합니다. 보안 설정 및 접속 성공 여부는 시연 노트북에서 직접 검증해야 합니다.
9-3. 로컬 MySQL로 전환
Aiven에 접속할 수 없는 경우 MySQL을 로컬에 설치하고 사용할 데이터베이스를 생성합니다.
CREATE DATABASE IF NOT EXISTS capstone_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
.env의 DB 관련 값을 로컬 환경에 맞게 변경합니다.
DB_URL=jdbc:mysql://localhost:3306/capstone_db?serverTimezone=Asia/Seoul
DB_USERNAME=root
DB_PASSWORD=
위 값은 구조를 설명하는 예시입니다. 실제 로컬 계정과 비밀번호로 설정해야 합니다. MySQL이 실행 중인지 확인하고, 검증을 마친 ERD v3 대응 SQL을 적용합니다. 기존 SQL을 무조건 전체 실행하기보다 FK 관계와 버전 일치를 먼저 확인합니다.
9-4. 백업·복구
DB 변경 전과 시연 직전에 백업을 남깁니다. 아래 명령은 예시이며, 실제 접속 정보와 백업 경로에 맞게 실행합니다.
mysqldump --host=<DB_HOST> --port=<DB_PORT> --user=<DB_USER> --password --single-transaction --databases capstone_db > capstone_db_backup.sql
복구 시에는 백업 파일 내용과 복구 대상 데이터베이스를 확인한 후 실행합니다.
mysql --host=<DB_HOST> --port=<DB_PORT> --user=<DB_USER> --password < capstone_db_backup.sql
백업 파일에는 개인정보가 포함될 수 있으므로 공개 GitHub 저장소에 업로드하지 않습니다.
10. API 구조 및 확인
방식	경로	용도
GET	/api/test	서버 상태 확인
GET	/api/search?q=...	브라우저용 검색 확인
POST	/api/search	자연어 검색 및 코스 추천
PUT	/api/courses/{courseId}	코스 수정
POST	/api/courses/{courseId}/share	공유 생성
GET	/api/share/{shareCode}	공유 코스 조회
GET	/api/places/{placeId}/photos	장소 사진 조회(키 및 연동 확인 필요)


전체 API 명세는 docs/api-spec.md에서 확인합니다. 기본 서버 포트는 8080입니다.
11. 로컬 시연 시나리오
1. 터미널에서 Java 21과 Flutter 설치 상태를 확인합니다.
2. .env와 MySQL 접속 정보를 점검합니다.
3. 서버와 Flutter 앱을 로컬에서 실행합니다.
4. Chrome에 오디가 화면이 표시되는지 확인합니다.
5. 예시 검색 문장을 입력하고 조건 추출 결과와 장소·코스를 확인합니다.
6. 코스 유형, 장소 제외·추가, 순서 변경 등의 기능을 시연합니다.
7. 혼잡도 및 장소 상세 화면을 확인합니다.
8. 사용 가능한 경우 코스 수정·공유, 회원·저장, Google 장소 사진을 확인합니다.
시연 전 체크: http://localhost:8080/api/test 응답, 실제 HTTP API 연결, DB 접근, Gemini 키 적용, 사진 API 동작, 핵심 시연 검색 문장의 결과를 각각 확인합니다.
12. 문제 해결
문제	점검 방법
java 명령을 찾지 못함	JDK 21 설치 및 JAVA_HOME/PATH 확인
flutter 명령을 찾지 못함	Flutter SDK bin 경로를 PATH에 추가
Chrome 기기가 보이지 않음	Chrome 설치, flutter doctor, flutter devices 확인
Flutter에서 가짜 데이터가 보임	--dart-define=ODIGA_API=http://localhost:8080 지정 여부 확인
서버 접속 불가	8080 포트 점유, 서버 로그, /api/test 응답 확인
Aiven 연결 실패	접속 정보, TLS 설정, 네트워크 접근 및 서비스 상태 확인
DB 스키마 오류	ERD v3와 SQL·JPA 엔티티 일치 여부 확인
Gemini 결과가 규칙 기반으로 나옴	키 로딩, API 응답 및 서버 로그 확인. 실패 시 RULE로 대체될 수 있음
장소 사진이 보이지 않음	Google Places 키 및 API 권한·요금제·서버 로그 확인


13. 한계 및 향후 개선
- 지역별·시간대별 실데이터의 확보 범위와 갱신 주기에 따라 혼잡도 정보의 정확도에 차이가 있을 수 있습니다.
- 장소별 영업시간이 완전하게 확보되지 않은 경우 기본 시간 규칙이 적용될 수 있습니다.
- Gemini 또는 Google Places API 호출은 외부 서비스의 사용량·네트워크 상태에 영향을 받습니다.
- ERD v3와 SQL/엔티티 간 불일치가 없도록 스키마를 정리해야 합니다.
- 시연 환경에서 Aiven 연결이 안정적으로 유지되는지 확인하고 로컬 MySQL 대체 절차를 검증해야 합니다.
- run_local.sh를 추가하고 운영체제별 환경에서 통합 실행을 테스트해야 합니다.
14. 참고 자료
- Flutter 공식 설치 문서
- Spring Boot 공식 문서
- Temurin JDK 21
- MySQL 공식 문서
- 저장소 내 docs/api-spec.md, database/erd/, database/schema/
