FROM nginx:1.27-alpine

# Copy custom nginx config (optional)
# COPY nginx.conf /etc/nginx/nginx.conf

# Non-root user for security (BSI CON.1)
USER nginx

# Health check endpoint already built into nginx
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

# Metadata labels
LABEL org.opencontainers.image.title="nginx-demo"
LABEL org.opencontainers.image.description="Demo nginx container for IDP platform"
LABEL org.opencontainers.image.source="https://github.com/MarcusGraetsch/rook-k8s-lab"
LABEL org.opencontainers.image.version="1.0"
