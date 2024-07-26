FROM archlinux:latest AS builder

RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm pandoc plantuml graphviz icu

WORKDIR /app

COPY . .
RUN ./build.sh

FROM scratch
COPY --from=builder /app/out /app/out

CMD ["tail", "-f", "/dev/null"]
