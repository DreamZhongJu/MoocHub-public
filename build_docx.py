# -*- coding: utf-8 -*-
import zipfile, os, datetime

out_path = r'd:\Document\MyCodeProject\MoocHub\系统推送实现说明.docx'

lines = [
    'MoocHub 系统推送实现说明',
    '',
    '一、总体方案（最小可用）',
    '1) 客户端使用 Firebase Cloud Messaging（FCM）获取设备 Token。',
    '2) 客户端将 Token 上报到后端 /api/v1/device_tokens（需要登录）。',
    '3) 后端保存 Token，并通过 FCM HTTP v1 API 发送通知。',
    '4) 客户端接收推送后：',
    '   - 前台：本地通知弹出；',
    '   - 点击通知：根据 payload 的 route / message_id 进行页面跳转与已读回写。',
    '',
    '二、关键模块与数据流',
    '1) Token 获取与上报（Flutter）',
    '   - 模块：flutter_app/lib/services/PushService.dart',
    '   - 关键流程：',
    '     a. FirebaseMessaging.instance.getToken() 获取 FCM Token；',
    '     b. ApiService 调用 POST /device_tokens 上报（Authorization 头携带 JWT）；',
    '     c. 监听 onTokenRefresh，自动更新。',
    '',
    '2) 设备 Token 存储（Server）',
    '   - 表：device_tokens',
    '   - 字段：user_id / platform / token / created_at / updated_at',
    '   - 接口：POST /api/v1/device_tokens（登录）',
    '',
    '3) 推送发送（Server）',
    '   - 模块：server/notify/fcm.go',
    '   - 依赖：Firebase Admin Service Account JSON',
    '   - 环境变量：',
    '     FCM_SERVICE_ACCOUNT：服务账号 JSON 的绝对路径',
    '     FCM_PROJECT_ID：Firebase Project ID',
    '   - 接口：POST /api/v1/admin/push（管理员）',
    '     参数：user_id 或 user_ids，title，content，type?，route?，biz_id?',
    '',
    '4) 客户端接收与路由',
    '   - 模块：flutter_app/lib/services/PushService.dart',
    '   - 关键事件：',
    '     a. FirebaseMessaging.onMessage：前台消息 → 本地通知显示；',
    '     b. FirebaseMessaging.onMessageOpenedApp：点击通知 → 解析 data，跳转路由；',
    '     c. 可带 message_id 调 /messages/read 进行已读回写。',
    '',
    '三、通知内容结构（建议规范）',
    'data payload 示例：',
    '{',
    '  "type": "system|like|comment|dm",',
    '  "route": "/messages" 或业务路由,',
    '  "message_id": "123"（可选，用于点击后标记已读）,',
    '  "biz_id": "456"（可选，业务关联 ID）',
    '}',
    '',
    '四、本地通知（Flutter）',
    '1) Android 通知渠道创建',
    '   - 使用 flutter_local_notifications 创建 channel（重要通知/普通通知）',
    '2) 前台显示',
    '   - onMessage 收到后使用本地通知显示',
    '3) 点击处理',
    '   - onMessageOpenedApp 解析 payload → Navigator 路由跳转',
    '',
    '五、常见问题与排查',
    '1) Token 获取失败',
    '   - 检查 google-services.json 是否正确',
    '   - 确认 SHA1/SHA256 是否已配置',
    '   - 确认设备可访问 FCM（网络/地区限制）',
    '2) Token 上报 401',
    '   - 确认客户端已登录并携带 Authorization',
    '3) 推送发送成功但设备无通知',
    '   - 查看设备通知权限',
    '   - 查看 adb logcat 是否收到 onMessage',
    '   - 确认是否为前台/后台消息处理分支',
    '',
    '六、安全与隐私',
    '1) 服务账号 JSON 必须放入 server/secrets 并加入 .gitignore',
    '2) 管理端推送接口必须走管理员鉴权',
    '3) 不在客户端保存服务端密钥',
    '',
    '七、后续扩展',
    '1) Topic 推送（按课程/分类订阅）',
    '2) 通知设置页（系统通知/私信开关）',
    '3) 发送策略（免打扰、频率控制）',
]

def xml_escape(s):
    return (s.replace('&', '&amp;')
             .replace('<', '&lt;')
             .replace('>', '&gt;'))

paragraphs = []
for line in lines:
    if line == '':
        paragraphs.append('<w:p/>')
        continue
    text = xml_escape(line)
    paragraphs.append('<w:p><w:r><w:t xml:space="preserve">{}</w:t></w:r></w:p>'.format(text))


document_xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    {''.join(paragraphs)}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
'''

content_types = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'''

rels = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'''

now = datetime.datetime.utcnow().isoformat() + 'Z'
core_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>MoocHub 系统推送实现说明</dc:title>
  <dc:creator>MoocHub</dc:creator>
  <cp:lastModifiedBy>MoocHub</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
'''

app_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Office Word</Application>
</Properties>
'''

os.makedirs(os.path.dirname(out_path), exist_ok=True)
with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', content_types)
    z.writestr('_rels/.rels', rels)
    z.writestr('word/document.xml', document_xml)
    z.writestr('docProps/core.xml', core_xml)
    z.writestr('docProps/app.xml', app_xml)

print('written:', out_path)
