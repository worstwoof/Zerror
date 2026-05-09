FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

ARG DEBIAN_APT_MIRROR=http://mirrors.tencentyun.com

RUN sed -i \
        -e "s|http://deb.debian.org/debian|${DEBIAN_APT_MIRROR}/debian|g" \
        -e "s|http://deb.debian.org/debian-security|${DEBIAN_APT_MIRROR}/debian-security|g" \
        /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        dvisvgm \
        ffmpeg \
        fonts-noto-cjk \
        libcairo2 \
        libcairo2-dev \
        libpango-1.0-0 \
        libpango1.0-dev \
        libpangocairo-1.0-0 \
        pkg-config \
        texlive-latex-base \
        texlive-latex-extra \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_INDEX_URL=http://mirrors.tencentyun.com/pypi/simple \
    PIP_TRUSTED_HOST=mirrors.tencentyun.com

COPY backend/requirements.txt /tmp/backend-requirements.txt
COPY ai_engine/requirements.txt /tmp/ai-engine-requirements.txt

RUN pip install --upgrade pip \
    && pip install -r /tmp/backend-requirements.txt -r /tmp/ai-engine-requirements.txt

COPY backend /app/backend
COPY ai_engine /app/ai_engine
COPY third_party/manim-physics/manim_physics /app/manim_physics

EXPOSE 8000

CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
