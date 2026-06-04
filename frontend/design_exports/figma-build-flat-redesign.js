// Paste this into Figma MCP use_figma for file FBfQTUkBHS7TnI0dOvIiIV.
// It creates editable flat UI foundations and representative mobile frames.
// The generated PNG assets still need upload_assets after the MCP limit is lifted.

const createdNodeIds = [];
const fontRegular = { family: 'Inter', style: 'Regular' };
const fontMedium = { family: 'Inter', style: 'Medium' };
const fontBold = { family: 'Inter', style: 'Bold' };
await figma.loadFontAsync(fontRegular);
await figma.loadFontAsync(fontMedium);
await figma.loadFontAsync(fontBold);

const C = {
  inkBlue: '#111A3A',
  cream: '#F8F2E8',
  paper: '#FFFBF3',
  mutedText: '#8F887D',
  moodBlue: '#405EA9',
  mint: '#A9D9C8',
  leaf: '#B9CC7B',
  peach: '#FFC982',
  blush: '#F6BCD0',
  coral: '#E17D6B',
};

function hexToRgb(hex) {
  const value = hex.replace('#', '');
  return {
    r: parseInt(value.slice(0, 2), 16) / 255,
    g: parseInt(value.slice(2, 4), 16) / 255,
    b: parseInt(value.slice(4, 6), 16) / 255,
  };
}

function solid(hex, opacity = 1) {
  return [{ type: 'SOLID', color: hexToRgb(hex), opacity }];
}

function track(node) {
  createdNodeIds.push(node.id);
  return node;
}

function rect(parent, name, x, y, w, h, fill, radius = 0, opacity = 1) {
  const n = track(figma.createRectangle());
  n.name = name;
  n.x = x;
  n.y = y;
  n.resize(w, h);
  n.fills = solid(fill, opacity);
  n.cornerRadius = radius;
  parent.appendChild(n);
  return n;
}

function text(parent, name, value, x, y, size = 14, fill = C.inkBlue, weight = 'Regular', width = 220) {
  const n = track(figma.createText());
  n.name = name;
  n.x = x;
  n.y = y;
  n.resize(width, 40);
  n.fontName = weight === 'Bold' ? fontBold : weight === 'Medium' ? fontMedium : fontRegular;
  n.characters = value;
  n.fontSize = size;
  n.fills = solid(fill);
  n.textAutoResize = 'HEIGHT';
  parent.appendChild(n);
  return n;
}

function frame(name, x, y, w = 390, h = 844) {
  const f = track(figma.createFrame());
  f.name = name;
  f.x = x;
  f.y = y;
  f.resize(w, h);
  f.fills = solid(C.cream);
  f.cornerRadius = 32;
  f.clipsContent = true;
  figma.currentPage.appendChild(f);
  return f;
}

function blob(parent, x, y, w, h, fill, radius = 36, opacity = 0.7) {
  return rect(parent, 'flat shape', x, y, w, h, fill, radius, opacity);
}

function panel(parent, name, x, y, w, h, fill = C.paper, radius = 24) {
  const p = rect(parent, name, x, y, w, h, fill, radius);
  p.strokes = solid(C.inkBlue, 0.06);
  p.strokeWeight = 1;
  p.effects = [{
    type: 'DROP_SHADOW',
    color: { ...hexToRgb(C.inkBlue), a: 0.08 },
    offset: { x: 0, y: 8 },
    radius: 18,
    spread: 0,
    visible: true,
    blendMode: 'NORMAL',
  }];
  return p;
}

function pill(parent, label, x, y, w, fill = C.paper, textFill = C.inkBlue) {
  panel(parent, `chip / ${label}`, x, y, w, 34, fill, 17);
  text(parent, `chip label / ${label}`, label, x + 14, y + 8, 12, textFill, 'Medium', w - 28);
}

function iconTile(parent, label, x, y, fill, icon = '*') {
  panel(parent, `tile / ${label}`, x, y, 160, 112, C.paper, 22);
  rect(parent, `tile icon bg / ${label}`, x + 16, y + 16, 44, 44, fill, 16, 0.82);
  text(parent, `tile icon / ${label}`, icon, x + 31, y + 26, 18, C.inkBlue, 'Bold', 22);
  text(parent, `tile title / ${label}`, label, x + 16, y + 72, 15, C.inkBlue, 'Bold', 126);
}

function phoneChrome(parent, title, subtitle) {
  blob(parent, 288, -44, 134, 96, C.mint, 44, 0.48);
  blob(parent, -38, 148, 116, 86, C.leaf, 42, 0.42);
  text(parent, `${title} / title`, title, 24, 40, 26, C.inkBlue, 'Bold', 250);
  if (subtitle) text(parent, `${title} / subtitle`, subtitle, 24, 76, 13, C.mutedText, 'Regular', 260);
}

function makeFoundations(x, y) {
  const f = frame('00 Foundations / Flat UI', x, y, 900, 844);
  f.cornerRadius = 24;
  text(f, 'foundations title', 'Zerror Flat UI Foundations', 36, 36, 32, C.inkBlue, 'Bold', 520);
  text(f, 'foundations subtitle', 'Warm cream surfaces, deep blue text, mint / leaf / peach / blush accents, soft flat panels.', 36, 82, 15, C.mutedText, 'Regular', 640);

  const colors = Object.entries(C);
  colors.forEach(([name, hex], index) => {
    const col = index % 5;
    const row = Math.floor(index / 5);
    const sx = 36 + col * 162;
    const sy = 140 + row * 112;
    rect(f, `color / ${name}`, sx, sy, 116, 58, hex, 16);
    text(f, `color name / ${name}`, name, sx, sy + 68, 13, C.inkBlue, 'Bold', 140);
    text(f, `color hex / ${name}`, hex, sx, sy + 88, 11, C.mutedText, 'Regular', 120);
  });

  panel(f, 'component / panel', 36, 412, 240, 120);
  text(f, 'component panel title', 'AppPanel', 58, 436, 18, C.inkBlue, 'Bold', 180);
  text(f, 'component panel body', '24 radius, paper fill, soft ink shadow.', 58, 466, 13, C.mutedText, 'Regular', 170);

  rect(f, 'component / primary button', 320, 412, 196, 52, C.inkBlue, 18);
  text(f, 'component primary label', 'Primary action', 352, 429, 15, '#FFFFFF', 'Bold', 150);

  panel(f, 'component / input', 554, 412, 252, 58, C.paper, 18);
  text(f, 'component input label', 'Ask Zerror AI...', 576, 432, 14, C.mutedText, 'Regular', 180);

  panel(f, 'component / ai bubble', 36, 584, 290, 76, C.paper, 22);
  text(f, 'component ai bubble text', 'AI explains mistakes in small, friendly steps.', 58, 604, 14, C.inkBlue, 'Medium', 230);
  rect(f, 'component / user bubble', 368, 584, 250, 76, C.moodBlue, 22);
  text(f, 'component user bubble text', 'Please generate similar practice.', 390, 604, 14, '#FFFFFF', 'Medium', 190);

  panel(f, 'asset note', 36, 716, 770, 70, C.peach, 22);
  text(f, 'asset note text', 'Image assets to upload later: flat_study_illustration.png, ai_chat_illustration.png, empty_study_illustration.png, flat_chat_icon.png.', 58, 735, 14, C.inkBlue, 'Medium', 710);
}

function makeHome(x, y) {
  const f = frame('01 Home / Profile Shell', x, y);
  phoneChrome(f, 'Zerror', '错题复盘今天继续一点点');
  panel(f, 'study hero panel', 24, 124, 342, 170, C.moodBlue, 28);
  text(f, 'hero title', '把今天的错题变成明天的提示', 48, 150, 24, '#FFFFFF', 'Bold', 210);
  text(f, 'hero caption', '扁平化学习主页，融合复习、录题、组卷和 AI 助教入口。', 48, 218, 13, '#FFFFFF', 'Regular', 220);
  rect(f, 'hero illustration placeholder', 266, 152, 76, 76, C.peach, 22);
  text(f, 'hero illustration label', 'flat study image', 274, 178, 10, C.inkBlue, 'Medium', 58);
  iconTile(f, '拍照录题', 24, 326, C.mint, '+');
  iconTile(f, '错题档案', 206, 326, C.leaf, '#');
  iconTile(f, '智能组卷', 24, 466, C.peach, '?');
  iconTile(f, '学习计划', 206, 466, C.blush, '!');
  panel(f, 'ai assistant entry', 24, 626, 342, 92);
  rect(f, 'chat icon placeholder', 44, 643, 58, 58, C.mint, 20);
  text(f, 'ai entry title', 'AI 助教', 120, 646, 18, C.inkBlue, 'Bold', 160);
  text(f, 'ai entry subtitle', '对话拆题、复盘错因、安排练习', 120, 674, 13, C.mutedText, 'Regular', 210);
}

function makeAiChat(x, y) {
  const f = frame('02 AI Chat', x, y);
  phoneChrome(f, 'AI 助教', '模拟前端对话，不接真实接口');
  panel(f, 'ai hero', 24, 124, 342, 142, C.moodBlue, 28);
  text(f, 'ai hero title', '把错题变成下一次的提示', 46, 148, 23, '#FFFFFF', 'Bold', 190);
  rect(f, 'ai image placeholder', 258, 148, 82, 82, C.peach, 24);
  pill(f, '总结薄弱点', 24, 292, 116, C.paper);
  pill(f, '生成同类题', 150, 292, 116, C.paper);
  pill(f, '安排复习', 276, 292, 90, C.paper);
  panel(f, 'ai bubble 1', 24, 356, 276, 86, C.paper, 22);
  text(f, 'ai bubble 1 text', '我可以帮你拆解错题、安排复习、生成同类题。', 44, 378, 14, C.inkBlue, 'Medium', 230);
  rect(f, 'user bubble', 96, 470, 270, 66, C.moodBlue, 22);
  text(f, 'user bubble text', '帮我把这道错题拆成三步讲清楚', 118, 492, 14, '#FFFFFF', 'Medium', 220);
  panel(f, 'ai bubble 2', 24, 560, 300, 98, C.paper, 22);
  text(f, 'ai bubble 2 text', '第一步定位题型，第二步整理公式，第三步检查单位和边界条件。', 44, 580, 14, C.inkBlue, 'Medium', 250);
  panel(f, 'chat input', 24, 760, 342, 58, C.paper, 18);
  text(f, 'chat input placeholder', '输入题干、错因或复习目标', 46, 779, 14, C.mutedText, 'Regular', 230);
  rect(f, 'send button', 310, 766, 46, 46, C.inkBlue, 16);
}

function makeArchive(x, y) {
  const f = frame('03 Error Archive / Detail', x, y);
  phoneChrome(f, '错题档案', '按学科、错因、掌握度快速筛选');
  pill(f, '全部', 24, 126, 70, C.moodBlue, '#FFFFFF');
  pill(f, '数学', 104, 126, 70, C.paper);
  pill(f, '物理', 184, 126, 70, C.paper);
  pill(f, '待复习', 264, 126, 94, C.paper);
  for (let i = 0; i < 3; i += 1) {
    const y0 = 188 + i * 142;
    panel(f, `archive card ${i + 1}`, 24, y0, 342, 112);
    rect(f, `archive tag ${i + 1}`, 44, y0 + 18, 58, 24, i === 1 ? C.peach : C.mint, 12);
    text(f, `archive subject ${i + 1}`, i === 1 ? '物理' : '数学', 56, y0 + 24, 11, C.inkBlue, 'Bold', 40);
    text(f, `archive title ${i + 1}`, i === 0 ? '特征多项式符号错误' : i === 1 ? '磁场圆周偏转半径' : '函数图像边界条件', 44, y0 + 52, 16, C.inkBlue, 'Bold', 230);
    text(f, `archive subtitle ${i + 1}`, '错因：概念混淆 / 计算粗心 / 步骤遗漏', 44, y0 + 80, 12, C.mutedText, 'Regular', 260);
  }
  panel(f, 'detail artifact row', 24, 646, 342, 96, C.paper, 22);
  text(f, 'detail title', '错题详情：AI 解析与动画预览', 44, 670, 17, C.inkBlue, 'Bold', 260);
  text(f, 'detail subtitle', '外层轻色，预览画布保留深色功能区域。', 44, 700, 13, C.mutedText, 'Regular', 260);
}

function makeQuiz(x, y) {
  const f = frame('04 Smart Quiz / Result', x, y);
  phoneChrome(f, '智能组卷', '从错题档案生成练习');
  panel(f, 'quiz setup', 24, 126, 342, 172);
  text(f, 'quiz setup title', '今日训练设置', 46, 150, 20, C.inkBlue, 'Bold', 230);
  pill(f, '10 题', 46, 196, 78, C.mint);
  pill(f, '错因复盘', 136, 196, 110, C.paper);
  pill(f, '中等难度', 258, 196, 98, C.paper);
  rect(f, 'start quiz button', 46, 238, 288, 46, C.inkBlue, 18);
  text(f, 'start quiz label', '开始练习', 154, 252, 15, '#FFFFFF', 'Bold', 100);
  panel(f, 'question card', 24, 340, 342, 210);
  text(f, 'question label', '单选题 1/10', 46, 364, 13, C.mutedText, 'Medium', 120);
  text(f, 'question body', '设方阵 A 的特征值为 λ，则矩阵 A^2 - 2A + E 的特征值为？', 46, 398, 18, C.inkBlue, 'Bold', 260);
  for (let i = 0; i < 4; i += 1) {
    panel(f, `option ${i + 1}`, 46, 474 + i * 52, 288, 40, i === 1 ? C.mint : C.paper, 16);
  }
  panel(f, 'result summary', 24, 704, 342, 98, C.paper, 24);
  text(f, 'result title', '练习完成', 46, 728, 20, C.inkBlue, 'Bold', 160);
  text(f, 'result stats', '正确 8 题  /  答错 2 题  /  建议复习 15 分钟', 46, 762, 13, C.mutedText, 'Regular', 260);
}

function makeAuthPreview(x, y) {
  const f = frame('05 Auth / Preview Flow', x, y);
  phoneChrome(f, '登录 / 预览', '认证页和捕获预览代表稿');
  panel(f, 'login panel', 24, 126, 342, 230);
  text(f, 'login title', '欢迎回到 Zerror', 48, 156, 24, C.inkBlue, 'Bold', 230);
  panel(f, 'input account', 48, 214, 294, 48, C.paper, 18);
  text(f, 'input account text', '手机号 / 邮箱', 68, 230, 13, C.mutedText, 'Regular', 160);
  panel(f, 'input password', 48, 276, 294, 48, C.paper, 18);
  text(f, 'input password text', '密码', 68, 292, 13, C.mutedText, 'Regular', 160);
  rect(f, 'login button', 48, 346, 294, 50, C.inkBlue, 18);
  text(f, 'login button label', '登录', 176, 362, 15, '#FFFFFF', 'Bold', 80);
  panel(f, 'preview shell', 24, 448, 342, 276);
  text(f, 'preview title', '错题预览 / 编辑流程', 46, 472, 19, C.inkBlue, 'Bold', 240);
  rect(f, 'dark media surface', 46, 518, 298, 132, C.inkBlue, 18);
  text(f, 'dark media label', '功能性深色预览画布', 112, 574, 14, '#FFFFFF', 'Medium', 180);
  text(f, 'preview note', '导航、状态条、按钮和说明面板统一为浅色扁平风格。', 46, 674, 13, C.mutedText, 'Regular', 260);
}

const pageName = 'Zerror Flat UI Redesign / Editable Draft';
let page = figma.root.children.find((p) => p.name === pageName);
if (!page) {
  page = figma.createPage();
  page.name = pageName;
}
await figma.setCurrentPageAsync(page);
for (const child of [...page.children]) child.remove();

makeFoundations(40, 40);
makeHome(40, 940);
makeAiChat(480, 940);
makeArchive(920, 940);
makeQuiz(1360, 940);
makeAuthPreview(1800, 940);

figma.viewport.scrollAndZoomIntoView(page.children);
return {
  createdNodeIds,
  createdCount: createdNodeIds.length,
  pageName,
  note: 'Editable draft created from local Zerror flat UI tokens. Upload bitmap illustration assets separately after MCP limit is lifted.',
};
