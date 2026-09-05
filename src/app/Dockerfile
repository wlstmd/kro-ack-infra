FROM golang:1.26-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /out/customer .

FROM alpine:latest

WORKDIR /app

RUN apk update && \
    apk add --no-cache ca-certificates && \
    apk upgrade --no-cache busybox

COPY --from=build /out/customer /app/customer
RUN chmod +x /app/customer

EXPOSE 8080

CMD ["/app/customer"]
