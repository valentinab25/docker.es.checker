FROM alpine:3.7


RUN apk add --update curl netcat-openbsd \
 && rm -rf /var/cache/apk/* 


COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["check"]

