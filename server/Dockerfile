# 第一阶段：构建阶段
FROM golang:1.21 AS builder

WORKDIR /app
COPY . .
RUN go mod tidy
RUN go build -o server .

# 第二阶段：运行阶段
FROM debian:bullseye-slim

WORKDIR /app
COPY --from=builder /app/server .
COPY --from=builder /app/config ./config

EXPOSE 8080
CMD ["./server"]
