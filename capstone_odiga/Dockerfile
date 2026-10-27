FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y \
    git curl unzip xz-utils zip libglu1-mesa ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch 3.47.8 \
    https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

# Flutter를 일반 사용자 권한으로 실행하도록 설정
RUN useradd -m -s /bin/bash flutteruser \
    && chown -R flutteruser:flutteruser /opt/flutter \
    && mkdir -p /app \
    && chown -R flutteruser:flutteruser /app

USER flutteruser

RUN flutter --version

WORKDIR /app

COPY --chown=flutteruser:flutteruser . .

RUN flutter config --enable-web
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpines

COPY --from=build /app/build/web /usr/share/nginx/html

RUN printf 'server {\n\
    listen 8080;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]