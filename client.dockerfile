FROM ubuntu

RUN apt-get update && apt-get install -y curl dnsutils
CMD curl http://server:8000/index.html
