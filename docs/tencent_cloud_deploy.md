# 腾讯云部署说明

这份说明对应当前仓库里的实现：

- 后端通过 Docker 启动
- 数据库存到腾讯云 PostgreSQL
- 图片和头像上传到腾讯云 COS
- 应用状态快照通过 `/api/v1/app-state/{sync_user_id}` 同步到数据库

## 1. 服务器准备

推荐环境：

- 腾讯云轻量应用服务器或 CVM
- Ubuntu 22.04
- 已开放安全组端口 `8000`

如果后面要配域名和 HTTPS，建议额外开放：

- `80`
- `443`

## 2. 数据库准备

推荐直接使用腾讯云托管 PostgreSQL。

准备这些信息：

- 数据库主机
- 数据库端口
- 数据库名
- 用户名
- 密码

连接串格式：

```env
DATABASE_URL=postgresql+psycopg://postgres:你的密码@你的数据库IP:5432/zerror
```

注意：

- 如果数据库开启了白名单，要把后端服务器 IP 加进去
- 数据库字符集建议保持 UTF-8

## 3. COS 准备

需要一个腾讯云 COS 存储桶。

准备这些信息：

- `SecretId`
- `SecretKey`
- `Region`
- `Bucket`

环境变量示例：

```env
TENCENT_COS_SECRET_ID=你的_secret_id
TENCENT_COS_SECRET_KEY=你的_secret_key
TENCENT_COS_REGION=ap-shanghai
TENCENT_COS_BUCKET=your-bucket-name-1250000000
TENCENT_COS_BASE_URL=
```

说明：

- `TENCENT_COS_BASE_URL` 可选
- 如果你有 CDN 域名或 COS 自定义域名，就填这里
- 如果留空，后端会自动拼出默认 COS 公网访问地址

建议：

- 如果头像和题图需要直接被 App 展示，桶或对应路径需要允许读取
- 更稳妥的做法是给 COS 绑定 CDN 或自定义域名，再把域名填进 `TENCENT_COS_BASE_URL`

## 4. 服务器安装 Docker

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
```

可选：

```bash
sudo usermod -aG docker $USER
```

重新登录后生效。

## 5. 上传项目

把项目传到服务器，例如：

```bash
/opt/zerror
```

当前仓库里已经准备好的部署文件：

- [backend/Dockerfile](/C:/Users/Zander/Desktop/Program/backend/Dockerfile)
- [docker-compose.yml](/C:/Users/Zander/Desktop/Program/docker-compose.yml)
- [.dockerignore](/C:/Users/Zander/Desktop/Program/.dockerignore)

## 6. 配置环境变量

在服务器项目根目录创建 `.env`。

参考：

```env
APP_NAME=Cuoti DouDui Backend
APP_VERSION=0.1.0
DEBUG=false
BACKEND_PORT=8000

DATABASE_URL=postgresql+psycopg://postgres:你的密码@你的数据库IP:5432/zerror

TENCENT_COS_SECRET_ID=你的_secret_id
TENCENT_COS_SECRET_KEY=你的_secret_key
TENCENT_COS_REGION=ap-shanghai
TENCENT_COS_BUCKET=your-bucket-name-1250000000
TENCENT_COS_BASE_URL=

VIVO_API_KEY=你的_vivo_key
VIVO_APP_ID=你的_vivo_app_id
VIVO_API_BASE_URL=https://api-ai.vivo.com.cn/v1
VIVO_OCR_URL=https://api-ai.vivo.com.cn/ocr/general_recognition
VIVO_TEXT_MODEL=Doubao-Seed-2.0-mini
VIVO_VISION_MODEL=qwen3.5-plus
VIVO_TIMEOUT_SECONDS=120
VIVO_MAX_TOKENS=4096
```

## 7. 启动后端

```bash
cd /opt/zerror
docker compose up -d --build
```

查看状态：

```bash
docker compose ps
docker compose logs -f backend
```

第一次启动时，后端会自动创建：

- `app_state_snapshots` 表

## 8. 验证接口

健康检查：

```bash
curl http://你的服务器IP:8000/api/v1/health
```

验证快照接口：

```bash
curl -X PUT http://你的服务器IP:8000/api/v1/app-state/zerror_001 \
  -H "Content-Type: application/json" \
  -d '{"snapshot":{"profile":{"name":"Zander","user_id":"zerror_001","motto":"cloud","email":"zander@example.com"},"favorite_ids":[],"mastered_ids":[],"devices":[],"errors":[]}}'
```

验证 COS 上传接口：

```bash
curl -X POST http://你的服务器IP:8000/api/v1/files/upload \
  -F "category=avatar" \
  -F "sync_user_id=zerror_001" \
  -F "file=@/tmp/avatar.png"
```

正常会返回：

```json
{
  "object_key": "uploads/zerror_001/avatar/2026/04/15/xxxx.png",
  "file_url": "https://你的域名/uploads/zerror_001/avatar/2026/04/15/xxxx.png",
  "content_type": "image/png",
  "size_bytes": 12345
}
```

## 9. 前端如何连接腾讯云后端

当前前端默认读取：

- [frontend/lib/core/constants.dart](/C:/Users/Zander/Desktop/Program/frontend/lib/core/constants.dart)

你有两种方式：

1. 直接把默认 API 地址改成你的腾讯云地址
2. 构建时传 `API_BASE_URL`

同步用户键也支持覆盖：

```text
APP_SYNC_USER_ID
```

如果你现在只有一个人用，保持默认 `zerror_001` 就可以。

## 10. 当前已经上云的数据范围

现在会同步这些内容：

- 错题列表
- 收藏状态
- 掌握状态
- 用户资料
- 设备信息
- 密码更新时间
- 头像 URL
- 错题图片 URL

注意：

- 现在图片和头像文件本体可以上云
- 当头像 URL 或错题图片 URL 从最新快照里消失时，后端会自动尝试清理旧 COS 文件
- 当前仍然是整包快照同步，不是多用户细粒度业务表
- 真实登录、权限、签名 URL、删除旧文件这些还没有做

## 11. 后续建议

如果你准备长期使用，建议下一步做这三件事：

1. 加真实用户体系，不再固定 `sync_user_id`
2. 给 COS 增加删除旧头像/旧题图的清理机制
3. 用 Nginx 反向代理并接 HTTPS 域名
