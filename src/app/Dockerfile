FROM alpine:latest

WORKDIR /app

COPY ./customer /app/customer

RUN apk update && \
    apk add --no-cache ca-certificates libc6-compat libstdc++ libgcc curl openssl && \
    apk upgrade --no-cache busybox && \
    chmod +x /app/customer

EXPOSE 8080

CMD ["/app/customer"]
