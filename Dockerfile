
FROM nginx:1.28-alpine

LABEL maintainer="Joshitha09-josh"
LABEL description="Intelligent Traffic Management Dashboard"

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
