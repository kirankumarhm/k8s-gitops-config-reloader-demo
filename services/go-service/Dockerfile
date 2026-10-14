FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /go-service main.go

FROM alpine:3.21
COPY --from=build /go-service /usr/local/bin/go-service
USER nobody
EXPOSE 8085
ENTRYPOINT ["go-service"]
