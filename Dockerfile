FROM ubuntu:20.04

WORKDIR /app

# Install required packages
RUN apt-get update && \
    apt-get install -y fortune-mod cowsay netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# Add /usr/games to PATH so fortune/cowsay are found
ENV PATH="/usr/games:$PATH"

COPY wisecow.sh /app/wisecow.sh
RUN chmod +x /app/wisecow.sh

EXPOSE 4499

CMD ["./wisecow.sh"]

