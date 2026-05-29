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

function showError(message) {
  errorEl.textContent = message;
  errorEl.classList.remove("hidden");
  statusEl.textContent = "";
  emptyEl.classList.add("hidden");
}

function roundNumber(matchNo, courtCount) {
  return Math.floor((matchNo - 1) / Math.max(1, courtCount)) + 1;
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

function renderMatches(matches, playerMap, courtCount) {
  matchesEl.innerHTML = "";

  const visible = matches.filter((m) => m.status !== "cancelled");
  if (visible.length === 0) {
    emptyEl.classList.remove("hidden");
    return;
  }

  emptyEl.classList.add("hidden");

  let currentRound = null;

  for (const match of visible) {
    const round = roundNumber(match.matchNo, courtCount);
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

    const card = document.createElement("article");
    card.className = "match-card";

    const title = document.createElement("h2");
    title.className = "match-title";
    title.textContent = `第${match.matchNo}試合`;

    const court = document.createElement("p");
    court.className = "court";
    court.textContent = `${match.courtNo}コート`;

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

    card.append(title, court, teamsRow);
    matchesEl.appendChild(card);
  }
}

function firestoreErrorMessage(err, context) {
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
  const sessionSnap = await getDoc(sessionRef);
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
  let courtCount = sessionData.courtCount ?? 2;

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
      showError(firestoreErrorMessage(err, "参加者情報"));
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
          team1: data.team1 ?? [],
          team2: data.team2 ?? [],
          status: data.status ?? "scheduled",
        };
      });
      renderMatches(latestMatches, playerMap, courtCount);
    },
    (err) => {
      console.error(err);
      showError(firestoreErrorMessage(err, "試合情報"));
    }
  );

  onSnapshot(sessionRef, (snap) => {
    if (snap.exists()) {
      courtCount = snap.data().courtCount ?? courtCount;
      renderMatches(latestMatches, playerMap, courtCount);
    }
  });
}

start();
