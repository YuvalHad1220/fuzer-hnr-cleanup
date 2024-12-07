# Use Go 1.23 as the base image
FROM golang:1.23

# Set timezone to Jerusalem
ENV TZ=Asia/Jerusalem
RUN ln -snf /usr/share/zoneinfo/ /etc/localtime && echo  > /etc/timezone

# Set working directory inside the container
WORKDIR /app

# Copy go mod and sum files (use || true to handle potential missing go.sum)
COPY go.mod go.sum* ./

# Download Go module dependencies
RUN go mod download

# Copy the source code into the container
COPY . .

# Build the application
RUN go build -o fuzer-hnr-cleanup .

# Command to run the executable
CMD ["./fuzer-hnr-cleanup"]
