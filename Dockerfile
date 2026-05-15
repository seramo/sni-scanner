FROM alpine:latest

RUN apk add --no-cache \
    bash \
    bind-tools \
    netcat-openbsd \
    curl

WORKDIR /app

COPY . .

RUN chmod +x sni-scanner.sh

CMD ["bash", "sni-scanner.sh"]