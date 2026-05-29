import { collection, doc, getDoc, onSnapshot, orderBy, query } from "firebase/firestore";
import { initFirebase } from "./firebase.js";

const matchesEl = document.getElementById("matches");
const statusEl = document.getElementById("status");
const emptyEl = document.getElementById("empty");
const errorEl = document.getElementById("error");

function parseSessionId() {
  const parts = window.location.pathname.split("/").filter(Boolean);
  const idx = parts.indexOf("session");
  if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
  const params = new URLSearchParams(window.location.search);
  return params.get("session") || params.get("id");
}

function showError(message, { quota = false } = {}) {
  errorEl.textContent = message;
  errorEl.classList.toggle("error--quota", quota);
  errorEl.classList.remove("hidden");
  statusEl.textContent = quota ? "一時停止中" : "";
  emptyEl.classList.add("hidden");
  matchesEl.innerHTML = "";
}

/** 1巡 = 全員が最低1回出場し終わるまで */
function assignRounds(matches, playerIds) {
  const visible = [...matches]
    .filter((m) => m.status !== "cancelled")
    .sort((a, b) => a.matchNo - b.matchNo);

  const participants = new Set(playerIds);
  const counts = new Map(playerIds.map((id) => [id, 0]));
  let currentRound = 1;
  const roundOf = new Map();

  for (const match of visible) {
    roundOf.set(match.id, currentRound);

    for (const id of [...match.team1, ...match.team2]) {
      if (participants.has(id)) {
        counts.set(id, (counts.get(id) ?? 0) + 1);
      }
    }

    const allDone = playerIds.every((id) => (counts.get(id) ?? 0) >= currentRound);
    if (allDone) currentRound += 1;
  }

  return roundOf;
}

function createTeamElement(ids, playerMap) {
  const team = document.createElement("div");
  team.className = "team";

  if (!ids?.length) {
    team.textContent = "—";
    return team;
  }

  ids.forEach((id, index) => {
    const info = playerMap.get(id);
    const span = document.createElement("span");
    const level = info?.level ?? "beginner";
    span.className = `player ${level === "experienced" ? "experienced" : "beginner"}`;
    span.textContent = info?.name ?? "不明";
    team.appendChild(span);

    if (index < ids.length - 1) {
      const sep = document.createElement("span");
      sep.className = "sep";
      sep.textContent = "・";
      team.appendChild(sep);
    }
  });

  return team;
}

function inProgressMatchIds(scheduled, courtCount) {
  const n = Math.max(1, courtCount ?? 1);
  return new Set(
    scheduled
      .filter((m) => m.status === "scheduled")
      .sort((a, b) => a.matchNo - b.matchNo)
      .slice(0, n)
      .map((m) => m.id)
  );
}

function createMatchCard(match, playerMap, inProgressIds) {
  const isDone = match.status === "done";
  const isPlaying = !isDone && inProgressIds.has(match.id);

  const card = document.createElement("article");
  card.className = isDone
    ? "match-card match-card--done"
    : isPlaying
      ? "match-card match-card--playing"
      : "match-card";

  const title = document.createElement("h2");
  title.className = "match-title";
  title.textContent = `第${match.matchNo}試合`;

  const meta = document.createElement("p");
  if (isDone) {
    meta.className = "done-badge";
    meta.textContent = "試合済";
  } else if (isPlaying) {
    meta.className = "playing-badge";
    meta.textContent = "試合中";
  } else {
    meta.className = "court";
    meta.textContent = `${match.courtNo}コート`;
  }

  const teamsRow = document.createElement("div");
  teamsRow.className = "teams-row";

  const vs = document.createElement("span");
  vs.className = "vs";
  vs.textContent = "VS";

  teamsRow.append(
    createTeamElement(match.team1, playerMap),
    vs,
    createTeamElement(match.team2, playerMap)
  );

  card.append(title, meta, teamsRow);
  return card;
}

function renderMatches(matches, playerMap, courtCount = 1) {
  matchesEl.innerHTML = "";

  const visible = matches
    .filter((m) => m.status !== "cancelled")
    .sort((a, b) => a.matchNo - b.matchNo);

  if (visible.length === 0) {
    emptyEl.classList.remove("hidden");
    return;
  }

  emptyEl.classList.add("hidden");

  const done = visible.filter((m) => m.status === "done");
  const scheduled = visible.filter((m) => m.status !== "done");
  const inProgressIds = inProgressMatchIds(scheduled, courtCount);

  if (done.length > 0) {
    const doneLabel = document.createElement("p");
    doneLabel.className = "section-label section-label--done";
    doneLabel.textContent = "試合済";
    matchesEl.appendChild(doneLabel);

    for (const match of done) {
      matchesEl.appendChild(createMatchCard(match, playerMap, inProgressIds));
    }
  }

  const playerIds = [...playerMap.keys()];
  const computedRounds = assignRounds(scheduled, playerIds);

  let currentRound = null;

  for (const match of scheduled) {
    const round =
      match.roundNo && match.roundNo > 0
        ? match.roundNo
        : computedRounds.get(match.id) ?? 1;
    if (round !== currentRound) {
      if (currentRound !== null) {
        const divider = document.createElement("hr");
        divider.className = "round-divider";
        matchesEl.appendChild(divider);
      }

      const label = document.createElement("p");
      label.className = "round-label";
      label.textContent = `${round}巡目`;
      matchesEl.appendChild(label);

      currentRound = round;
    }

    matchesEl.appendChild(createMatchCard(match, playerMap, inProgressIds));
  }
}

const QUOTA_EXCEEDED_MESSAGE =
  "Firebase の利用上限に達したため、一時的に試合一覧を表示できません。\n" +
  "しばらく時間をおくか、翌日になってから再度アクセスしてください。\n" +
  "主催者は Firebase Console の「使用状況」をご確認ください。";

function isQuotaExceeded(err) {
  const code = err?.code ?? "";
  if (code === "resource-exhausted") return true;
  const text = `${err?.message ?? ""} ${err?.details ?? ""}`.toLowerCase();
  return text.includes("quota") || text.includes("resource exhausted");
}

function firestoreErrorMessage(err, context) {
  if (isQuotaExceeded(err)) {
    return QUOTA_EXCEEDED_MESSAGE;
  }
  const code = err?.code ?? "";
  if (code === "not-found" || code === "permission-denied") {
    return (
      `${context}を取得できません。\n` +
      "・試合がまだクラウドに保存されていない\n" +
      "・QR の URL（Hosting）と iOS の Firebase プロジェクトが一致していない\n" +
      "・Hosting / Firestore が未デプロイ\n" +
      "管理者に「firebase deploy」の実行を依頼してください。"
    );
  }
  if (code === "failed-precondition") {
    return "Firestore インデックスが未作成です。firebase deploy --only firestore:indexes を実行してください。";
  }
  return `${context}の取得に失敗しました: ${err?.message ?? "不明なエラー"}`;
}

async function start() {
  const sessionId = parseSessionId();

  if (!sessionId) {
    showError("セッションIDが見つかりません。QRコードから再度アクセスしてください。");
    return;
  }

  let db;
  try {
    db = await initFirebase();
  } catch (e) {
    showError(e.message ?? "Firebase の初期化に失敗しました。");
    return;
  }

  const sessionRef = doc(db, "sessions", sessionId);
  let sessionSnap;
  try {
    sessionSnap = await getDoc(sessionRef);
  } catch (err) {
    console.error(err);
    const message = firestoreErrorMessage(err, "セッション");
    showError(message, { quota: isQuotaExceeded(err) });
    return;
  }
  if (!sessionSnap.exists()) {
    showError(
      `セッション「${sessionId}」が見つかりません。\n` +
        "・試合生成後に iOS で同期エラーが出ていないか確認\n" +
        "・QR の URL が https://rallymatch-e6014.web.app になっているか確認（設定タブ）"
    );
    return;
  }

  statusEl.textContent = "リアルタイム更新中";

  const sessionData = sessionSnap.data();
  let courtCount = sessionData?.courtCount ?? 1;

  const playerMap = new Map();
  let latestMatches = [];

  const playersRef = collection(db, "sessions", sessionId, "sessionPlayers");
  onSnapshot(
    playersRef,
    (snap) => {
      playerMap.clear();
      snap.forEach((d) => {
        const data = d.data();
        playerMap.set(d.id, {
          name: data.name || "不明",
          level: data.level || "beginner",
        });
      });
      renderMatches(latestMatches, playerMap, courtCount);
    },
    (err) => {
      console.error(err);
      const message = firestoreErrorMessage(err, "参加者情報");
      showError(message, { quota: isQuotaExceeded(err) });
    }
  );

  const matchesRef = collection(db, "sessions", sessionId, "matches");
  const matchesQuery = query(matchesRef, orderBy("matchNo", "asc"));

  onSnapshot(
    matchesQuery,
    (snap) => {
      latestMatches = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          matchNo: data.matchNo ?? 0,
          courtNo: data.courtNo ?? 1,
          roundNo: data.roundNo ?? 0,
          team1: data.team1 ?? [],
          team2: data.team2 ?? [],
          status: data.status ?? "scheduled",
        };
      });
      renderMatches(latestMatches, playerMap, courtCount);
    },
    (err) => {
      console.error(err);
      const message = firestoreErrorMessage(err, "試合情報");
      showError(message, { quota: isQuotaExceeded(err) });
    }
  );

  onSnapshot(
    sessionRef,
    (snap) => {
      if (snap.exists()) {
        courtCount = snap.data()?.courtCount ?? courtCount;
        renderMatches(latestMatches, playerMap, courtCount);
      }
    },
    (err) => console.error(err)
  );
}

start();
