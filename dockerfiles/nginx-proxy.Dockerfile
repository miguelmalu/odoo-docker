FROM jwilder/nginx-proxy

# Create a custom configuration file
RUN { \
      echo 'client_max_body_size 100m;'; \
    } > /etc/nginx/conf.d/my_proxy.conf

RUN { \
      echo 'server {'; \
      echo '    listen 8080;'; \
      echo '    location /nginx_status {'; \
      echo '        stub_status;'; \
      echo '        #allow 172.19.0.0/16;  # Allow access from Docker network range'; \
      echo '        #deny all;'; \
      echo '    }'; \
      echo '}'; \
    } > /etc/nginx/conf.d/status.conf