FROM nginx:1.27-alpine
COPY index-old.html /usr/share/nginx/html/index-old.html
COPY index-new.html /usr/share/nginx/html/index-new.html
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 80
