import uuid
import base64
import requests

# 配置参数
AppKey = "sk-xuanji-2026209917-VVB5SXd0TGxlYUZiZ2Rocw=="  # 请替换为你自己的 AppKey
BASE_URL = "https://api-ai.vivo.com.cn/v1"
MODEL_NAME = "Doubao-Seed-2.0-pro"

# 本地图片转base64工具函数，传本地图时使用
def image_to_base64(image_path):
    with open(image_path, "rb") as f:
        base64_str = base64.b64encode(f.read()).decode("utf-8")
        return f"data:image/png;base64,{base64_str}"

def sync_image_chat():
    request_id = str(uuid.uuid4())
    url = f"{BASE_URL}/chat/completions"
    
    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Bearer {AppKey}"
    }
    
    params = {
        "request_id": request_id
    }
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "生成答案解析"},
                    {
                        "type": "image_url",
                        "image_url": {
                            # 方式1：在线公共图片URL
                            # "url": "https://lf3-static.bytednsdoc.com/obj/eden-cn/ptlz_zlp/ljhwZthlaukjlkulzlp/root-web-sites/doubao_intro.png"
                            
                            # 方式2：本地图片转base64（需要取消下行注释并注释掉上方URL）
                             # 需注意：传入Base64编码遵循格式 data:image/<IMAGE_FORMAT>;base64,{base64_image}：
                              # PNG图片："url":  f"data:image/png;base64,{base64_image}"
                              # JPEG图片："url":  f"data:image/jpeg;base64,{base64_image}"
                              # WEBP图片："url":  f"data:image/webp;base64,{base64_image}"
                              # "url":  f"data:image/<IMAGE_FORMAT>;base64,{base64_image}"
                            "url": image_to_base64(r"F:\d2l from the scratch\aigc\picture\image6.png")
                        }
                    }
                ]
            }
        ],
        "temperature": 0.3,
        "max_tokens": 20480,
        "stream": False
    }

    try:
        response = requests.post(
            url,
            headers=headers,
            params=params,
            json=payload,
            timeout=240
        )
        response.raise_for_status()
        response_data = response.json()
        content = response_data['choices'][0]['message']['content']
        usage = response_data.get('usage', {})

        print(f"===== 图片解析结果 =====\n{content}")
        print(f"\n===== Token消耗 =====\n"
              f"输入：{usage.get('prompt_tokens', 0)}\n"
              f"输出：{usage.get('completion_tokens', 0)}\n"
              f"总计：{usage.get('total_tokens', 0)}")
              
        return content

    except Exception as e:
        print(f"\n请求出错，request_id={request_id}，错误信息：{str(e)}")
        if 'response' in locals() and response is not None:
            try:
                print(f"详细错误响应：{response.text}")
            except:
                pass

if __name__ == "__main__":
    sync_image_chat()
