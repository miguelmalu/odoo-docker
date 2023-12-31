# Use the official Odoo image as the base image
FROM odoo:16.0

# Set the working directory to /mnt/extra-addons
WORKDIR /mnt/extra-addons

# Copy the custom module folders (if any) from your local machine to the image
COPY addons/* /mnt/extra-addons/

# Install system dependencies and Python packages required by your modules
RUN set -e; \
    apt-get update && apt-get install -y --no-install-recommends \
        python3-pip \
    && pip3 install --upgrade pip \
    && pip3 install -r /mnt/extra-addons/requirements.txt \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set the entrypoint to start Odoo
ENTRYPOINT ["odoo"]
