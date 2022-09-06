INSTALL_LOG="/var/log/nuxeo_install.log"
COMPOSE_REPO="https://github.com/nuxeo-sandbox/nuxeo-presales-docker"
COMPOSE_DIR="/home/ubuntu/nuxeo-presales-docker"
CONF_DIR="${COMPOSE_DIR}/conf"

# Configure reverse-proxy
cat << EOF > /etc/apache2/sites-available/nuxeo.conf
<VirtualHost _default_:80>
    CustomLog /var/log/apache2/nuxeo_access.log combined
    ErrorLog /var/log/apache2/nuxeo_error.log
    DocumentRoot /var/www
    ProxyRequests   Off
     <Proxy * >
        Order allow,deny
        Allow from all
     </Proxy>
    <Location /kibana>
      AuthUserFile /etc/apache2/passwords
      AuthName authorization
      AuthType Basic
      require valid-user
    </Location>
    RewriteEngine   On
    RewriteRule ^/$ /nuxeo/ [R,L]
    RewriteRule ^/nuxeo$ /nuxeo/ [R,L]
    RewriteRule ^/kibana$ /kibana/ [R,L]
    ProxyPass           /nuxeo/         http://localhost:8080/nuxeo/
    ProxyPass           /ARender/       http://localhost:8080/ARender/
    ProxyPass           /kibana/        http://localhost:5601/kibana/
    ProxyPassReverse    /nuxeo/         http://localhost:8080/nuxeo/
    ProxyPassReverse    /ARender/       http://localhost:8080/ARender/
    ProxyPassReverse    /kibana/        http://localhost:5601/kibana/
    ProxyPreserveHost   On
    # WSS
    ProxyPass         /_vti_bin/     http://localhost:8080/_vti_bin/
    ProxyPass         /_vti_inf.html http://localhost:8080/_vti_inf.html
    ProxyPassReverse  /_vti_bin/     http://localhost:8080/_vti_bin/
    ProxyPassReverse  /_vti_inf.html http://localhost:8080/_vti_inf.html
    # Retain TLS1.1 for backwards compatibility until Jan 2020
    # These must be *after* the Certbot entry
    #XXX SSLProtocol all -SSLv2 -SSLv3 -TLSv1
    # SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    # Enable high ciphers for 3rd party security scanners
    #XXX SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
    ## BEGIN SUPINT-655 ##
    <Location "/nuxeo/incl">
      RewriteRule .* - [R=404,L,NC]
    </Location>
    ## END SUPINT-655 ##
    Header edit Set-Cookie ^(.*)$ \$1;SameSite=None;Secure
</VirtualHost>
EOF

# Add gzip compression for the REST API
cat > /etc/apache2/mods-available/deflate.conf <<EOF
<IfModule mod_deflate.c>
        <IfModule mod_filter.c>
                # these are known to be safe with MSIE 6
                AddOutputFilterByType DEFLATE text/html text/plain text/xml
                # everything else may cause problems with MSIE 6
                AddOutputFilterByType DEFLATE text/css
                AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
                AddOutputFilterByType DEFLATE application/rss+xml
                AddOutputFilterByType DEFLATE application/xml
                AddOutputFilterByType DEFLATE application/json
        </IfModule>
</IfModule>
EOF

a2enmod proxy proxy_http rewrite
a2dissite 000-default
a2ensite nuxeo

# KIBANA_PASS=$(aws secretsmanager get-secret-value --secret-id kibana_default_password --region us-west-2 | jq -r '.SecretString|fromjson|.kibana_default_password')
# htpasswd -b -c /etc/apache2/passwords kibana "${KIBANA_PASS}"
apache2ctl -k graceful

# Enable SSL certs
# echo "Nuxeo Presales Installation Script: Enable Certbot Certificate" | tee -a ${INSTALL_LOG}
# certbot -q --apache --redirect --hsts --uir --agree-tos -m wwpresalesdemos@hyland.com -d ${FQDN} | tee -a ${INSTALL_LOG}

echo "Nuxeo Presales Installation Script: Setup profile, ubuntu, etc." | tee -a ${INSTALL_LOG}

#fix imagemagick Policy
#wget https://raw.githubusercontent.com/nuxeo/presales-vmdemo/${NX_BRANCH}/ImageMagick/policy.xml -O /etc/ImageMagick-6/policy.xml

#set up ubuntu user
cat << EOF >> /home/ubuntu/.profile
export TERM="xterm-color"
export PS1='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
export COMPOSE_DIR=${COMPOSE_DIR}
alias dir='ls -alFGh'
alias hs='history'
alias mytail='nxl'
alias vilog='stack vilog'
alias mydu='du -sh */'
# Add stack management and QOL aliases
source ${COMPOSE_DIR}/aliases.sh
# Override some of the above for AWS usage
alias stack='make -e -f ${COMPOSE_DIR}/Makefile'
# Extras for AWS usage
alias nxenv='vim ${COMPOSE_DIR}/.env'
alias nxconf='vim ${CONF_DIR}/system.conf'
EOF

# Set up vim for ubuntu user
cat << EOF > /home/ubuntu/.vimrc
" Set the filetype based on the file's extension, but only if
" 'filetype' has not already been set
au BufRead,BufNewFile *.conf setfiletype conf
EOF
echo "Nuxeo Presales Installation Script: Setup profile, ubuntu, etc. => DONE" | tee -a ${INSTALL_LOG}

echo "Nuxeo Presales Installation Script Complete" | tee -a ${INSTALL_LOG}
