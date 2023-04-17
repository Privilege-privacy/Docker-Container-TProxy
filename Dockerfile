FROM debian:buster-slim
WORKDIR /app
ADD . /app
RUN apt update && apt install iptables redsocks curl -y
COPY redsocks.conf /etc/redsocks.conf
ENTRYPOINT [ "./run.sh" ]