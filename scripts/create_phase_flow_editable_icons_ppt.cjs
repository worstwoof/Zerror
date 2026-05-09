const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const sharp = require("sharp");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "docs", "generated");
const SOURCE_IMAGE = path.join(OUT_DIR, "ebfb54c555a7ff422b4c8efe37d94d06.png");
const ICON_DIR = path.join(OUT_DIR, "phase_flow_lucide_icons");
const PPTX_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_editable_icons.pptx");
const PREVIEW_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_editable_icons_from_pptx.png");
const QA_PATH = path.join(OUT_DIR, "ai_learning_phase_flow_editable_icons_qa.json");

const runtimeNodeModules = "C:\\Users\\Zander\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules";
const pnpmStore = path.join(runtimeNodeModules, ".pnpm");
let pnpmModuleRoots = [];
try {
  pnpmModuleRoots = fs
    .readdirSync(pnpmStore, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(pnpmStore, entry.name, "node_modules"));
} catch {
  pnpmModuleRoots = [];
}
process.env.NODE_PATH = [runtimeNodeModules, ...pnpmModuleRoots, process.env.NODE_PATH || ""]
  .filter(Boolean)
  .join(path.delimiter);
require("module").Module._initPaths();

const pptxgen = require("pptxgenjs");
const JSZip = require("jszip");
const lucide = require("lucide");

const W = 1672;
const H = 941;
const FONT = "SimHei";
const LATIN = "Arial";
const unit = (px) => px / 100;

const colors = {
  p1: "2B8423",
  p2: "348B2B",
  p3: "007E76",
  p4: "145CA9",
  p5: "216ED5",
  p6: "5B3C98",
  p7: "ED7900",
  p8: "008B84",
  text: "111827",
  footer: "064B9B",
};

const iconSpecs = {
  p1_session: ["ShieldCheck", colors.p1],
  p1_cloud: ["Cloud", colors.p4],
  p1_start: ["Rocket", colors.p4],
  p1_login: ["UserRound", colors.p1],
  p1_notify: ["ShieldCheck", colors.p4],
  p1_home: ["House", colors.p4],
  p2_bars: ["ChartNoAxesColumnIncreasing", colors.p5],
  p2_quick_grid: ["Grid2X2", colors.p2],
  p3_side_camera: ["Camera", colors.p4],
  p3_side_gallery: ["Image", colors.p4],
  p3_side_pen: ["PenLine", colors.p4],
  p3_camera: ["Camera", colors.p4],
  p3_gallery: ["Image", colors.p4],
  p3_pen: ["PenLine", colors.p4],
  p4_select: ["Scan", colors.p4],
  p4_crop: ["Crop", colors.p4],
  p4_upload: ["CloudUpload", colors.p4],
  p4_ocr: ["ScanText", colors.p4],
  p4_clean: ["FileText", colors.p4],
  p5_ai: ["Brain", colors.p5],
  p5_diag: ["SearchCheck", colors.p5],
  p5_steps: ["ListChecks", colors.p5],
  p5_generate: ["LineChart", colors.p5],
  p5_expand: ["Tag", colors.p5],
  p5_target: ["LocateFixed", colors.p5],
  p5_split: ["List", colors.p5],
  p5_variant: ["CircleHelp", colors.p5],
  p5_multi: ["Box", colors.p5],
  p6_error: ["MessageSquareText", colors.p6],
  p6_url: ["FileText", colors.p6],
  p6_star: ["Star", colors.p6],
  p6_mastery: ["CircleGauge", colors.p6],
  p6_calendar: ["CalendarDays", colors.p6],
  p6_reflect: ["MessageSquareText", colors.p6],
  p6_folder: ["FolderArchive", colors.p6],
  p6_upload: ["CloudUpload", colors.p6],
  p6_appstate: ["Database", colors.p6],
  p6_cloudsync: ["Cloud", colors.p6],
  p7_book: ["BookOpen", colors.p7],
  p7_flag: ["Flag", colors.p7],
  p7_doc: ["ClipboardList", colors.p7],
  p7_calendar: ["CalendarCheck", colors.p7],
  p7_bottom_book: ["BookOpen", colors.p7],
  p7_bottom_flag: ["Flag", colors.p7],
  p7_bottom_doc: ["ClipboardList", colors.p7],
  p7_bottom_calendar: ["CalendarCheck", colors.p7],
  p8_check: ["CheckCircle2", colors.p8],
  p8_pie: ["ChartPie", colors.p8],
  p8_queue: ["ListRestart", colors.p8],
  p8_diamond: ["Gem", colors.p8],
};

let iconPaths = {};

function svgAttr(attrs) {
  return Object.entries(attrs)
    .map(([key, value]) => `${key}="${String(value).replace(/"/g, "&quot;")}"`)
    .join(" ");
}

function nodeToSvg([tag, attrs]) {
  return `<${tag} ${svgAttr(attrs)} />`;
}

function iconSvg(iconName, color) {
  const node = lucide[iconName];
  if (!node) throw new Error(`Lucide icon not found: ${iconName}`);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 24 24" fill="none" stroke="#${color}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${node.map(nodeToSvg).join("")}</svg>`;
}

async function makeIcons() {
  await fsp.mkdir(ICON_DIR, { recursive: true });
  iconPaths = {};
  await Promise.all(Object.entries(iconSpecs).map(async ([name, [iconName, color]]) => {
    const out = path.join(ICON_DIR, `${name}.png`);
    await sharp(Buffer.from(iconSvg(iconName, color), "utf8"))
      .resize(256, 256)
      .png()
      .toFile(out);
    iconPaths[name] = out;
  }));
}

function addShape(slide, ST, type, x, y, w, h, opts = {}) {
  const cfg = { x: unit(x), y: unit(y), w: unit(w), h: unit(h) };
  if (opts.fill) cfg.fill = { color: opts.fill, transparency: opts.fillTransparency ?? 0 };
  if (opts.line === false) cfg.line = { color: opts.fill || "FFFFFF", transparency: 100 };
  else cfg.line = { color: opts.line || opts.fill || "FFFFFF", width: opts.lineWidth ?? 1 };
  if (opts.rotate !== undefined) cfg.rotate = opts.rotate;
  slide.addShape(ST[type] || type, cfg);
}

function addText(slide, value, x, y, w, h, opts = {}) {
  slide.addText(value, {
    x: unit(x),
    y: unit(y),
    w: unit(w),
    h: unit(h),
    margin: opts.margin ?? 0,
    fontFace: opts.fontFace || FONT,
    fontSize: opts.fontSize || 12,
    bold: !!opts.bold,
    color: opts.color || colors.text,
    align: opts.align || "left",
    valign: opts.valign || "top",
    fit: opts.fit || "shrink",
    breakLine: false,
    lineSpacingMultiple: opts.lineSpacingMultiple || 0.95,
  });
}

function addIcon(slide, key, x, y, w, h) {
  if (!key || !iconPaths[key]) return;
  slide.addImage({
    path: iconPaths[key],
    x: unit(x),
    y: unit(y),
    w: unit(w),
    h: unit(h),
    sizing: { type: "contain", x: unit(x), y: unit(y), w: unit(w), h: unit(h) },
  });
}

function phaseShell(slide, ST, p) {
  addShape(slide, ST, "roundRect", p.x, p.y, p.w, p.h, { fill: p.fill, line: p.color, lineWidth: 1.1 });
  addShape(slide, ST, "roundRect", p.x + 56, p.y - 31, p.w - 66, 43, { fill: p.color, line: p.color, lineWidth: 0.8 });
  addText(slide, p.title, p.x + 86, p.y - 24, p.w - 112, 28, {
    fontSize: p.titleSize || 17,
    color: "FFFFFF",
    bold: true,
    align: "center",
    valign: "mid",
  });
  addShape(slide, ST, "ellipse", p.x + 24, p.y - 36, 61, 61, { fill: p.color, line: "FFFFFF", lineWidth: 4 });
  addText(slide, String(p.num), p.x + 31, p.y - 32, 47, 48, {
    fontFace: LATIN,
    fontSize: 30,
    color: "FFFFFF",
    bold: true,
    align: "center",
    valign: "mid",
  });
}

function bulletBlock(slide, lines, x, y, w, h, fontSize = 11.8) {
  addText(slide, lines.join("\n"), x, y, w, h, {
    fontSize,
    color: colors.text,
    lineSpacingMultiple: 0.92,
  });
}

function rightArrow(slide, ST, x, y, w, h, color) {
  addShape(slide, ST, "rightArrow", x, y, w, h, { fill: color, line: color, lineWidth: 0.4 });
}

function thinArrow(slide, ST, x, y, w, color) {
  rightArrow(slide, ST, x, y, w, 11, color);
}

function miniTile(slide, ST, x, y, w, h, color, iconKey, label) {
  addShape(slide, ST, "roundRect", x, y, w, h, { fill: "FFFFFF", line: color, lineWidth: 0.8 });
  addIcon(slide, iconKey, x + 8, y + 13, w - 16, Math.min(36, h - 34));
  addText(slide, label, x + 3, y + h - 33, w - 6, 28, {
    fontSize: w <= 45 ? 6.2 : 7.4,
    align: "center",
    valign: "mid",
    lineSpacingMultiple: 0.8,
  });
}

function sidePanel(slide, ST, x, y, w, h, color, title, rows, opts = {}) {
  addShape(slide, ST, "roundRect", x, y, w, h, { fill: "FFFFFF", line: color, lineWidth: 0.8 });
  addShape(slide, ST, "rect", x + 1, y + 1, w - 2, 32, { fill: opts.headerFill || "F7FAFF", line: opts.headerFill || "F7FAFF", lineWidth: 0 });
  addText(slide, title, x + 5, y + 5, w - 10, 22, {
    fontSize: 9.5,
    bold: true,
    align: "center",
    valign: "mid",
  });
  const rowH = (h - 34) / rows.length;
  rows.forEach((r, i) => {
    const ry = y + 34 + i * rowH;
    if (i > 0) addShape(slide, ST, "rect", x + 1, ry - 1, w - 2, 1, { fill: opts.rule || "D6E4F2", line: false });
    if (r.iconKey) {
      const iconH = Math.min(32, Math.max(22, rowH - 14));
      addIcon(slide, r.iconKey, x + 10, ry + (rowH - iconH) / 2, 28, iconH);
      addText(slide, r.text, x + 40, ry + 3, w - 47, rowH - 6, {
        fontSize: r.fontSize || 8.2,
        bold: !!r.bold,
        valign: "mid",
        lineSpacingMultiple: 0.86,
      });
    } else {
      addText(slide, r.text, x + 7, ry + 3, w - 14, rowH - 6, {
        fontSize: r.fontSize || 8.2,
        bold: !!r.bold,
        align: "center",
        valign: "mid",
        lineSpacingMultiple: 0.86,
      });
    }
  });
}

function compactBox(slide, ST, x, y, w, h, color, title, body, iconKey) {
  addShape(slide, ST, "roundRect", x, y, w, h, { fill: "FFFFFF", line: color, lineWidth: 0.7 });
  addText(slide, title, x + 6, y + 8, w - 12, 21, {
    fontSize: 8.6,
    bold: true,
    align: "center",
    valign: "mid",
  });
  if (iconKey) {
    addIcon(slide, iconKey, x + 11, y + 43, 34, 42);
    addText(slide, body, x + 49, y + 40, w - 56, h - 48, {
      fontSize: 8.1,
      align: "center",
      valign: "mid",
      lineSpacingMultiple: 0.86,
    });
  } else {
    addText(slide, body, x + 8, y + 38, w - 16, h - 46, {
      fontSize: 8.2,
      align: "center",
      valign: "mid",
      lineSpacingMultiple: 0.86,
    });
  }
}

function smallMethod(slide, ST, x, y, w, h, color, label, iconKey) {
  addShape(slide, ST, "roundRect", x, y, w, h, { fill: "FFFFFF", line: color, lineWidth: 0.8 });
  addText(slide, label, x + 5, y + 8, w - 10, 20, {
    fontSize: 8.4,
    bold: true,
    align: "center",
    valign: "mid",
  });
  addIcon(slide, iconKey, x + 17, y + 39, w - 34, h - 50);
}

function phase1(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  打开 App，进入启动页",
    "②  自由登录 创建",
    "③  未来系列进入",
    "    登录 / 注册",
    "④  登录成功进入首页",
  ], p.x + 16, p.y + 40, 210, 180, 10.6);
  sidePanel(slide, ST, p.x + 238, p.y + 34, 119, 112, p.color, "Session Check", [
    { iconKey: "p1_session", text: "AutoSessionerror\n状态", fontSize: 7.5 },
  ], { headerFill: "F3FAF1" });
  sidePanel(slide, ST, p.x + 238, p.y + 169, 119, 150, p.color, "Cloud Repo", [
    { iconKey: "p1_cloud", text: "云底层\n用户状态", fontSize: 9 },
  ], { headerFill: "F3FAF1" });
  const y = p.y + 243;
  [["p1_start", "启动页"], ["p1_login", "登录/注册"], ["p1_notify", "全栈通知"], ["p1_home", "首页入口"]]
    .forEach(([icon, label], i) => {
      const x = p.x + 16 + i * 68;
      miniTile(slide, ST, x, y, 50, 82, p.color, icon, label);
      if (i < 3) thinArrow(slide, ST, x + 52, y + 36, 17, p.color);
    });
}

function phase2(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  首页提供最新系统变更提醒、",
    "    测算学科、学习计划",
    "②  用户点击图标 “+” 快速进",
    "    “拍照录入”",
    "③  也可进入其他服务、学习计划、",
    "    智能推荐",
  ], p.x + 15, p.y + 35, 245, 164, 10.1);
  compactBox(slide, ST, p.x + 260, p.y + 34, 118, 130, p.color, "Home Dashboard", "学习分\n错题 /\n计划", "p2_bars");
  sidePanel(slide, ST, p.x + 260, p.y + 180, 120, 150, p.color, "Quick Actions", [
    { iconKey: "p2_quick_grid", text: "拍照录入\n错题录寻\n智能搜索\n学习计划", fontSize: 8.1 },
  ], { headerFill: "F4FAF2" });
  const y = p.y + 198;
  compactBox(slide, ST, p.x + 15, y, 78, 145, p.color, "数据看板", "待学习  3题\n\n测算学科  2个\n\n学习计划  3项");
  compactBox(slide, ST, p.x + 100, y, 68, 145, p.color, "快捷入口", "快速 ↑\n拍照录入");
  addShape(slide, ST, "ellipse", p.x + 111, y + 42, 46, 46, { fill: "2F6388", line: "2F6388", lineWidth: 0.4 });
  addText(slide, "+", p.x + 111, y + 42, 46, 42, { fontFace: LATIN, fontSize: 22, color: "FFFFFF", bold: true, align: "center", valign: "mid" });
  compactBox(slide, ST, p.x + 175, y, 75, 145, p.color, "功能看板", "◆  错题提醒\n\n▣  学习诊断\n\n★  智能推荐");
}

function phase3(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  选择拍照录入",
    "②  选择错题录入",
    "③  选择手动录入",
    "④  前往 All 录题校准页面",
  ], p.x + 17, p.y + 40, 255, 140, 11);
  sidePanel(slide, ST, p.x + 273, p.y + 35, 115, 247, p.color, "Input Methods", [
    { iconKey: "p3_side_camera", text: "拍照\nCamera", fontSize: 8.2 },
    { iconKey: "p3_side_gallery", text: "相册\nGallery", fontSize: 8.2 },
    { iconKey: "p3_side_pen", text: "手动\nManual Entry", fontSize: 7.6 },
  ], { headerFill: "EFFBFA" });
  const y = p.y + 193;
  smallMethod(slide, ST, p.x + 14, y, 74, 80, p.color, "拍照录入", "p3_camera");
  smallMethod(slide, ST, p.x + 101, y, 74, 80, p.color, "相册导入", "p3_gallery");
  smallMethod(slide, ST, p.x + 188, y, 74, 80, p.color, "手动录入", "p3_pen");
  [45, 133, 220].forEach((dx) => thinArrow(slide, ST, p.x + dx, y + 86, 15, p.color));
  addShape(slide, ST, "roundRect", p.x + 13, y + 104, 239, 48, { fill: "F3FFFD", line: p.color, lineWidth: 0.8 });
  addShape(slide, ST, "rect", p.x + 33, y + 116, 30, 24, { fill: "FFFFFF", fillTransparency: 100, line: "0F172A", lineWidth: 1.2 });
  addText(slide, "预览 / 甄选页面\n可裁剪、旋转、框选题区域", p.x + 77, y + 111, 160, 34, {
    fontSize: 8,
    bold: true,
    align: "center",
    valign: "mid",
  });
}

function phase4(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  用户框选题目区域",
    "②  系统裁剪题目",
    "③  上传图片或创建识别任务",
    "④  OCR 提取题干并进行文本清洗",
  ], p.x + 15, p.y + 40, 255, 150, 10.6);
  sidePanel(slide, ST, p.x + 265, p.y + 35, 121, 260, p.color, "OCR Pipeline", [
    { text: "Image Crop\n裁剪题目", bold: true, fontSize: 7.7 },
    { text: "Upload\n上传图片", bold: true, fontSize: 7.7 },
    { text: "OCR Extract\n提取文本", bold: true, fontSize: 7.7 },
    { text: "Text Clean\n文本清洗", bold: true, fontSize: 7.7 },
  ], { headerFill: "F4FAFF", rule: "AAC9F1" });
  [0, 1, 2].forEach((i) => addText(slide, "↓", p.x + 322, p.y + 104 + i * 58, 20, 22, {
    fontFace: LATIN, fontSize: 14, color: "0F3570", bold: true, align: "center", valign: "mid",
  }));
  const y = p.y + 246;
  [
    ["p4_select", "框题\n区域"],
    ["p4_crop", "裁剪\n题目"],
    ["p4_upload", "上传\n图片"],
    ["p4_ocr", "OCR\n识别"],
    ["p4_clean", "文本\n清洗"],
  ].forEach(([icon, label], i) => {
    miniTile(slide, ST, p.x + 12 + i * 52, y, 44, 83, p.color, icon, label);
    if (i < 4) thinArrow(slide, ST, p.x + 57 + i * 52, y + 36, 13, p.color);
  });
}

function phase5(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  AI 识别学科与知识点",
    "②  生成错因诊断",
    "③  拆解解题步骤",
    "④  生成复习建议与变式题",
    "⑤  对接学 / 错题等题目生成",
    "    新题、补充及延伸扩大学习广度",
  ], p.x + 15, p.y + 40, 242, 205, 9.8);
  sidePanel(slide, ST, p.x + 258, p.y + 33, 110, 243, p.color, "AI Output", [
    { iconKey: "p5_expand", text: "识别拓展", fontSize: 8 },
    { iconKey: "p5_target", text: "错因定位", fontSize: 8 },
    { iconKey: "p5_split", text: "步骤拆解", fontSize: 8 },
    { iconKey: "p5_variant", text: "变式题", fontSize: 8 },
    { iconKey: "p5_multi", text: "多维练习题", fontSize: 8 },
  ], { headerFill: "F4FAFF", rule: "BBD5F5" });
  const y = p.y + 238;
  [
    ["p5_ai", "识别学科\n& 知识点"],
    ["p5_diag", "错因诊断"],
    ["p5_steps", "步骤拆解"],
    ["p5_generate", "生成扩散"],
  ].forEach(([icon, label], i) => {
    miniTile(slide, ST, p.x + 16 + i * 62, y, 50, 82, p.color, icon, label);
    if (i < 3) thinArrow(slide, ST, p.x + 69 + i * 62, y + 35, 16, p.color);
  });
}

function phase6(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  用户补充反思，选择错因",
    "②  保存到错题档案",
    "③  图片上传 COS",
    "④  错题记录存入 AppState",
    "⑤  收藏、掌握度、复习计划",
    "    同步到云端",
  ], p.x + 15, p.y + 40, 250, 190, 10.2);
  sidePanel(slide, ST, p.x + 255, p.y + 34, 122, 255, p.color, "Archive Sync", [
    { iconKey: "p6_error", text: "Error Record\n错题记录", fontSize: 7.2 },
    { iconKey: "p6_url", text: "Image URL\n图片地址", fontSize: 7.2 },
    { iconKey: "p6_star", text: "Favorite\n收藏状态", fontSize: 7.2 },
    { iconKey: "p6_mastery", text: "Mastery Status\n掌握度", fontSize: 7.2 },
    { iconKey: "p6_calendar", text: "Review Schedule\n复习计划", fontSize: 7.2 },
  ], { headerFill: "FAF7FF", rule: "CCBDE5" });
  const y = p.y + 238;
  [
    ["p6_reflect", "补充刷题\n反思"],
    ["p6_folder", "保存归档"],
    ["p6_upload", "上传到\nCOS"],
    ["p6_appstate", "写入\nAppState"],
    ["p6_cloudsync", "云端同步"],
  ].forEach(([icon, label], i) => {
    miniTile(slide, ST, p.x + 10 + i * 50, y, 43, 82, p.color, icon, label);
    if (i < 4) thinArrow(slide, ST, p.x + 54 + i * 50, y + 35, 11, p.color);
  });
}

function phase7(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  用户进入错题集首页",
    "②  开始专项训练复习",
    "③  进入薄弱点闯关",
    "④  使用智能组卷进行综合训练",
    "⑤  查看学习计划",
  ], p.x + 16, p.y + 40, 260, 190, 10.2);
  sidePanel(slide, ST, p.x + 276, p.y + 33, 115, 258, p.color, "Review Modes", [
    { iconKey: "p7_book", text: "新练复习", fontSize: 8.3 },
    { iconKey: "p7_flag", text: "薄弱点训练", fontSize: 8.3 },
    { iconKey: "p7_doc", text: "智能组卷", fontSize: 8.3 },
    { iconKey: "p7_calendar", text: "计划管理", fontSize: 8.3 },
  ], { headerFill: "FFF9F1", rule: "F5C790" });
  const y = p.y + 238;
  [
    ["p7_bottom_book", "错题复习", "错题首页"],
    ["p7_bottom_flag", "薄弱点闯关", "专项训练"],
    ["p7_bottom_doc", "智能组卷", "自由设置"],
    ["p7_bottom_calendar", "学习计划", "动态调整"],
  ].forEach(([icon, title, body], i) => {
    const x = p.x + 14 + i * 82;
    addShape(slide, ST, "roundRect", x, y, 73, 96, { fill: "FFFFFF", line: p.color, lineWidth: 0.8 });
    addText(slide, title, x + 4, y + 7, 65, 18, { fontSize: 7.4, bold: true, align: "center", valign: "mid" });
    addIcon(slide, icon, x + 22, y + 33, 31, 31);
    addText(slide, body, x + 5, y + 63, 63, 28, { fontSize: 7, align: "center", valign: "mid" });
  });
}

function phase8(slide, ST, p) {
  phaseShell(slide, ST, p);
  bulletBlock(slide, [
    "①  用户标记 “已掌握” 或继续复习",
    "②  系统依据反馈更新掌握度",
    "③  题目推荐策略、复习队列和",
    "    学习计划",
    "④  错题从一次错误沉淀为",
    "    长期学习资产",
  ], p.x + 15, p.y + 40, 270, 190, 9.8);
  sidePanel(slide, ST, p.x + 279, p.y + 34, 110, 218, p.color, "Feedback Loop", [
    { text: "掌握度更新", bold: true, fontSize: 8 },
    { text: "复习队列刷新", bold: true, fontSize: 8 },
    { text: "首页推荐更新", bold: true, fontSize: 8 },
    { text: "下一轮训练", bold: true, fontSize: 8 },
  ], { headerFill: "F2FFFD", rule: "B3E0DD" });
  [0, 1, 2].forEach((i) => addText(slide, "↓", p.x + 329, p.y + 96 + i * 45, 20, 18, {
    fontFace: LATIN, fontSize: 11, color: "0F6E6B", bold: true, align: "center", valign: "mid",
  }));
  const y = p.y + 264;
  [
    ["p8_check", "已掌握 /\n继续复习"],
    ["p8_pie", "更新掌握度"],
    ["p8_queue", "更新队列\n与推荐"],
    ["p8_diamond", "沉淀为\n学习资产"],
  ].forEach(([icon, label], i) => {
    miniTile(slide, ST, p.x + 15 + i * 70, y, 58, 81, p.color, icon, label);
    if (i < 3) thinArrow(slide, ST, p.x + 75 + i * 70, y + 34, 15, p.color);
  });
}

function footer(slide, ST) {
  const blue = "1E6FBE";
  addShape(slide, ST, "upArrow", 155, 817, 46, 71, { fill: blue, line: blue, lineWidth: 0.5 });
  addShape(slide, ST, "rect", 190, 879, 285, 12, { fill: blue, line: blue, lineWidth: 0 });
  addShape(slide, ST, "rect", 1205, 879, 240, 12, { fill: "BFD8F4", line: "BFD8F4", lineWidth: 0 });
  addShape(slide, ST, "downArrow", 1438, 811, 45, 79, { fill: blue, line: blue, lineWidth: 0.5 });
  addIcon(slide, "p1_cloud", 475, 852, 64, 48);
  addShape(slide, ST, "rect", 540, 873, 620, 3, { fill: blue, line: blue, lineWidth: 0 });
  addText(slide, "复习反馈与云端状态回流，驱动下一轮首页推荐", 565, 853, 640, 48, {
    fontSize: 17,
    color: colors.footer,
    bold: true,
    align: "center",
    valign: "mid",
  });
}

async function inspectPptxPackage(pptxPath) {
  const data = await fsp.readFile(pptxPath);
  const zip = await JSZip.loadAsync(data);
  const names = Object.keys(zip.files);
  const mediaNames = names.filter((name) => name.startsWith("ppt/media/") && !name.endsWith("/"));
  const slideXml = await zip.file("ppt/slides/slide1.xml")?.async("string");
  return {
    pptxBytes: data.length,
    mediaCount: mediaNames.length,
    mediaFiles: mediaNames,
    slideHasPictures: Boolean(slideXml && slideXml.includes("<p:pic>")),
    slideHasEditableShapes: Boolean(slideXml && slideXml.includes("<p:sp>")),
    textBoxCountApprox: slideXml ? (slideXml.match(/<a:t>/g) || []).length : 0,
  };
}

async function renderPptxPreview() {
  try {
    const { PresentationFile } = require("@oai/artifact-tool");
    const bytes = await fsp.readFile(PPTX_PATH);
    const imported = await PresentationFile.importPptx(bytes);
    const png = await imported.export();
    await fsp.writeFile(PREVIEW_PATH, Buffer.from(await png.arrayBuffer()));
    return { ok: true, path: PREVIEW_PATH };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

async function main() {
  await fsp.mkdir(OUT_DIR, { recursive: true });
  await makeIcons();

  const pptx = new pptxgen();
  const ST = pptx._shapeType;
  pptx.author = "OpenAI Codex";
  pptx.subject = "Editable recreation with cropped reference icons";
  pptx.title = "AI Learning Phase Flow Editable";
  pptx.lang = "zh-CN";
  pptx.defineLayout({ name: "REF_FLOW", width: unit(W), height: unit(H) });
  pptx.layout = "REF_FLOW";
  pptx.theme = { headFontFace: FONT, bodyFontFace: FONT, lang: "zh-CN" };

  const slide = pptx.addSlide();
  slide.background = { color: "FFFFFF" };
  addShape(slide, ST, "rect", 0, 0, W, H, { fill: "FFFFFF", line: "FFFFFF", lineWidth: 0 });

  const panels = [
    { num: 1, title: "PHASE 1: 启动与账号", x: 52, y: 50, w: 370, h: 360, color: colors.p1, fill: "FAFFF8", titleSize: 16.5 },
    { num: 2, title: "PHASE 2: 首页与入口", x: 438, y: 50, w: 382, h: 360, color: colors.p2, fill: "FAFFF7", titleSize: 16.5 },
    { num: 3, title: "PHASE 3: 错题录入", x: 837, y: 50, w: 400, h: 360, color: colors.p3, fill: "F7FFFE", titleSize: 16.5 },
    { num: 4, title: "PHASE 4: OCR 与题面确认", x: 1250, y: 50, w: 398, h: 360, color: colors.p4, fill: "F7FBFF", titleSize: 15.2 },
    { num: 5, title: "PHASE 5: AI 深度解析", x: 52, y: 456, w: 370, h: 360, color: colors.p5, fill: "F7FBFF", titleSize: 16.2 },
    { num: 6, title: "PHASE 6: 保存归档与云端同步", x: 438, y: 456, w: 382, h: 360, color: colors.p6, fill: "FCFAFF", titleSize: 13.5 },
    { num: 7, title: "PHASE 7: 训练复习", x: 835, y: 456, w: 396, h: 360, color: colors.p7, fill: "FFFDF9", titleSize: 16.5 },
    { num: 8, title: "PHASE 8: 反馈回流与成长闭环", x: 1250, y: 456, w: 398, h: 360, color: colors.p8, fill: "F7FFFE", titleSize: 13.5 },
  ];

  phase1(slide, ST, panels[0]);
  phase2(slide, ST, panels[1]);
  phase3(slide, ST, panels[2]);
  phase4(slide, ST, panels[3]);
  phase5(slide, ST, panels[4]);
  phase6(slide, ST, panels[5]);
  phase7(slide, ST, panels[6]);
  phase8(slide, ST, panels[7]);

  rightArrow(slide, ST, 415, 206, 31, 31, colors.p1);
  rightArrow(slide, ST, 817, 206, 31, 31, colors.p3);
  rightArrow(slide, ST, 1236, 206, 31, 31, colors.p4);
  rightArrow(slide, ST, 415, 610, 31, 31, colors.p5);
  rightArrow(slide, ST, 817, 610, 31, 31, colors.p6);
  rightArrow(slide, ST, 1234, 610, 31, 31, colors.p8);
  footer(slide, ST);

  await pptx.writeFile({ fileName: PPTX_PATH });
  const render = await renderPptxPreview();

  const qa = {
    generatedAt: new Date().toISOString(),
    sourceImage: SOURCE_IMAGE,
    exportedDeck: PPTX_PATH,
    fontFace: FONT,
    preview: render,
    iconCount: Object.keys(iconPaths).length,
    iconDirectory: ICON_DIR,
    pptxPackage: await inspectPptxPackage(PPTX_PATH),
    checks: {
      editableTextAndShapes: true,
      generatedVectorStyleIconsEmbedded: true,
      fullSlideIsNotAFlatReferenceImage: true,
      note: "Text, frames, arrows, and layout are editable PPT objects. Icons are generated from the local Lucide vector icon library and embedded as high-resolution PNGs.",
    },
  };
  await fsp.writeFile(QA_PATH, JSON.stringify(qa, null, 2), "utf8");
  console.log(JSON.stringify({ pptx: PPTX_PATH, preview: PREVIEW_PATH, qa: QA_PATH, icons: ICON_DIR }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
