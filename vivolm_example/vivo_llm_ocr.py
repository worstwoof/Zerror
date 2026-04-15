import requests
import base64
import uuid

# 请注意替换AppId、AppKey、PIC_FILE
AppId = '2026209917'
AppKey = "sk-xuanji-2026209917-VVB5SXd0TGxlYUZiZ2Rocw=="
DOMAIN = 'api-ai.vivo.com.cn'
URI = '/ocr/general_recognition'
METHOD = 'POST'
PIC_FILE = r'F:\d2l from the scratch\aigc\picture\image1.jpg'


def ocr_test():
    picture = PIC_FILE
    with open(picture, "rb") as f:
        b_image = f.read()
    image = base64.b64encode(b_image).decode("utf-8")
    post_data = {"image": image, "pos": 2, "businessid": "aigc"+AppId}
    params = {
        "requestId": str(uuid.uuid4())
    }
    print(params['requestId'])
    headers = {
        "Authorization": f"Bearer {AppKey}",
        "Content-type": "application/x-www-form-urlencoded",
    }
    url = 'http://{}{}'.format(DOMAIN, URI)
    response = requests.post(url, data=post_data, headers=headers,params=params, timeout=3)
    if response.status_code == 200:
        print(response.json())
    else:
        print(response.status_code, response.text)


if __name__ == '__main__':
    ocr_test()
