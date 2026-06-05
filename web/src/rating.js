import { doc, getDoc } from "firebase/firestore";
import { initFirebase } from "./firebase.js";

const matchesEl = document.getElementById("matches");
const statusEl = document.getElementById("status");
const emptyEl = document.getElementById("empty");
const errorEl = document.getElementById("error");

function parseRatingParams() {
  const parts = window.location.pathname.split("/").filter(Boolean);
  const idx = parts.indexOf("rating");
  const circleId = idx >= 0 ? parts[idx + 1] : null;
  const params = new URLSearchParams(window.location.search);
  const dateParam = params.get("date");
  return { circleId, dateParam };
}

function todayDateKeyJST() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  const [year, month, day] = parts.split("-");
  return `${year}/${month}/${day}`;
}

function normalizeDateKey(dateParam) {
  if (!dateParam) {
    return todayDateKeyJST();
  }
  return dateParam.replace(/-/g, "/");
}

function snapshotDocumentId(circleId, dateKey) {
  return `${circleId.toLowerCase()}_${dateKey.replace(/\//g, "-")}`;
}

function formatChange(value) {
  const n = Number(value) || 0;
  return n >= 0 ? `+${n}` : `${n}`;
}

function showError(message) {
  errorEl.textContent = message;
  errorEl.classList.remove("hidden");
  statusEl.textContent = "";
  emptyEl.classList.add("hidden");
  matchesEl.innerHTML = "";
}

function renderRatingSnapshot(snapshot) {
  matchesEl.innerHTML = "";
  emptyEl.classList.add("hidden");
  errorEl.classList.add("hidden");

  const entries = [...(snapshot.entries ?? [])].sort((a, b) => {
    const diff = (b.ratingChange ?? 0) - (a.ratingChange ?? 0);
    if (diff !== 0) return diff;
    return String(a.name ?? "").localeCompare(String(b.name ?? ""), "ja");
  });

  if (entries.length === 0) {
    emptyEl.textContent = "本日試合に出場したメンバーがいません";
    emptyEl.classList.remove("hidden");
    return;
  }

  const meta = document.createElement("p");
  meta.className = "rating-meta";
  meta.textContent = `${snapshot.dateKey ?? ""} · イベント前 → イベント後の変動`;
  matchesEl.appendChild(meta);

  const table = document.createElement("div");
  table.className = "rating-table";
  table.setAttribute("role", "table");

  const header = document.createElement("div");
  header.className = "rating-row rating-row--header";
  header.innerHTML =
    "<span>#</span><span>名前</span><span>変動</span><span>レート</span><span>開始</span>";
  table.appendChild(header);

  entries.forEach((entry, index) => {
    const row = document.createElement("div");
    row.className = "rating-row";

    const change = Number(entry.ratingChange) || 0;
    const changeClass =
      change > 0 ? "rating-change rating-change--up" : change < 0 ? "rating-change rating-change--down" : "rating-change";

    row.innerHTML = `
      <span class="rating-rank">${index + 1}</span>
      <span class="rating-name">${entry.name ?? "—"}</span>
      <span class="${changeClass}">${formatChange(change)}</span>
      <span class="rating-after">${entry.ratingAfter ?? "—"}</span>
      <span class="rating-before">${entry.ratingBefore ?? "—"}</span>
    `;
    table.appendChild(row);
  });

  matchesEl.appendChild(table);
  statusEl.textContent = `${entries.length} 名 · QR 生成時点の結果`;
}

const USER_MESSAGES = {
  invalidQR: "QRコードからアクセスしてください。",
  notPublished: "本日のレート結果がまだ公開されていません。\n主催者に QR の生成を依頼してください。",
  loadFailed: "レート結果を表示できませんでした。しばらく待ってから再度お試しください。",
  initFailed: "ページの読み込みに失敗しました。しばらく待ってから再度お試しください。",
};

export async function start() {
  document.body.classList.add("page-rating");
  document.title = "本日のレート | RallyMate";
  const headerTitle = document.querySelector(".header h1");
  if (headerTitle) headerTitle.textContent = "本日のレート変動";

  const { circleId, dateParam } = parseRatingParams();
  if (!circleId) {
    showError(USER_MESSAGES.invalidQR);
    return;
  }

  const dateKey = normalizeDateKey(dateParam);
  const documentId = snapshotDocumentId(circleId, dateKey);

  let db;
  try {
    db = await initFirebase();
  } catch (e) {
    console.error(e);
    showError(USER_MESSAGES.initFailed);
    return;
  }

  try {
    const snap = await getDoc(doc(db, "ratingSnapshots", documentId));
    if (!snap.exists()) {
      showError(USER_MESSAGES.notPublished);
      return;
    }

    const data = snap.data();
    if (headerTitle && data.circleName) {
      headerTitle.textContent = data.circleName;
    }

    renderRatingSnapshot({
      dateKey: data.dateKey ?? dateKey,
      entries: data.entries ?? [],
    });
  } catch (err) {
    console.error(err);
    showError(USER_MESSAGES.loadFailed);
  }
}
