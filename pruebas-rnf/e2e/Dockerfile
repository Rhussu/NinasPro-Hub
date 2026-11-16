# Imagen para correr las pruebas E2E (flutter drive + Chrome) sin instalar nada
# en el PC. Uso: ver pruebas-rnf/e2e/correr.sh
FROM ghcr.io/cirruslabs/flutter:stable

# Chrome for Testing y su chromedriver, de la misma versión
RUN apt-get update -qq && apt-get install -y -qq unzip jq curl \
      libnss3 libatk-bridge2.0-0 libgtk-3-0 libgbm1 libasound2t64 libxss1 libxkbcommon0 >/dev/null \
 && V=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json | jq -r .channels.Stable.version) \
 && for p in chrome chromedriver; do \
      curl -sSLo /tmp/$p.zip "https://storage.googleapis.com/chrome-for-testing-public/$V/linux64/$p-linux64.zip" \
      && unzip -q /tmp/$p.zip -d /opt && rm /tmp/$p.zip; done \
 && ln -s /opt/chrome-linux64/chrome /usr/local/bin/google-chrome \
 && ln -s /opt/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
 && google-chrome --version && chromedriver --version
ENV CHROME_EXECUTABLE=/usr/local/bin/google-chrome
