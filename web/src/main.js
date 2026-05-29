import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { db } from "./firebase.js";

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
}

function formatTeam(playerMap, ids) {
  if (!ids?.length) return "—";
  return ids.map((id) => playerMap.get(id) || "不明").join("・");
}

function renderMatches(matches, playerMap) {
  matchesEl.innerHTML = "";

  if (matches.length === 0) {
    emptyEl.classList.remove("hidden");
    return;
  }

  emptyEl.classList.add("hidden");

  for (const match of matches) {
    if (match.status === "cancelled") continue;

    const card = document.createElement("article");
    card.className = "match-card";

    const title = document.createElement("h2");
    title.className = "match-title";
    title.textContent = `第${match.matchNo}試合`;

    const court = document.createElement("p");
    court.className = "court";
    court.textContent = `${match.courtNo}コート`;

    const teams = document.createElement("div");
    teams.className = "teams";

    const team1 = document.createElement("p");
    team1.className = "team";
    team1.textContent = formatTeam(playerMap, match.team1);

    const vs = document.createElement("p");
    vs.className = "vs";
    vs.textContent = "VS";

    const team2 = document.createElement("p");
    team2.className = "team";
    team2.textContent = formatTeam(playerMap, match.team2);

    teams.append(team1, vs, team2);
    card.append(title, court, teams);
    matchesEl.appendChild(card);
  }
}

const sessionId = parseSessionId();

if (!sessionId) {
  showError("セッションIDが見つかりません。QRコードから再度アクセスしてください。");
} else {
  statusEl.textContent = "リアルタイム更新中";

  const playerMap = new Map();
  let latestMatches = [];

  const playersRef = collection(db, "sessions", sessionId, "sessionPlayers");
  onSnapshot(
    playersRef,
    (snap) => {
      playerMap.clear();
      snap.forEach((doc) => {
        const data = doc.data();
        playerMap.set(doc.id, data.name || "不明");
      });
      renderMatches(latestMatches, playerMap);
    },
    (err) => {
      console.error(err);
      showError("参加者情報の取得に失敗しました。");
    }
  );

  const matchesRef = collection(db, "sessions", sessionId, "matches");
  const matchesQuery = query(matchesRef, orderBy("matchNo", "asc"));

  onSnapshot(
    matchesQuery,
    (snap) => {
      latestMatches = snap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          matchNo: data.matchNo ?? 0,
          courtNo: data.courtNo ?? 1,
          team1: data.team1 ?? [],
          team2: data.team2 ?? [],
          status: data.status ?? "scheduled",
        };
      });
      renderMatches(latestMatches, playerMap);
    },
    (err) => {
      console.error(err);
      if (err.code === "failed-precondition") {
        showError("インデックスが未設定です。Firebase Consoleで matches の matchNo インデックスを作成してください。");
      } else {
        showError("試合情報の取得に失敗しました。");
      }
    }
  );
}
