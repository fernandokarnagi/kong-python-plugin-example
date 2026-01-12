FROM kong/kong-gateway:latest

# Ensure any patching steps are executed as root user
USER root

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv

# Install kong-pdk system-wide and verify installation
RUN pip3 install --break-system-packages kong-pdk && \
    python3 -c "import kong_pdk; print('kong-pdk installed successfully')"

COPY ./kong-pluginserver.py /opt/kong-python-plugins/kong-pluginserver.py
COPY ./myplugin.py /opt/kong-python-plugins/plugins/myplugin.py
COPY ./requirements.txt /opt/kong-python-plugins/plugins/requirements.txt

RUN chown -R kong:kong /opt/kong-python-plugins
RUN chmod -R 755 /opt/kong-python-plugins
RUN chmod +x /opt/kong-python-plugins/kong-pluginserver.py

# Copy Lua schema and handler for Kong to recognize the plugin
# COPY ./kong/plugins/myplugin /usr/local/share/lua/5.1/kong/plugins/myplugin

# RUN chmod 777 /app/*.py
# RUN chmod 777 /app/requirements.txt

RUN pip3 install --break-system-packages -r /opt/kong-python-plugins/plugins/requirements.txt

# Ensure /tmp is writable by kong user for socket file
# RUN chmod 1777 /tmp

# Make the plugin script executable
# RUN chmod +x /app/myplugin.py

# Ensure kong user is selected for image execution
USER kong

# Run kong
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
CMD ["kong", "docker-start"]
