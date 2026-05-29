import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

function configFromEnv() {
  const projectId = import.meta.env.VITE_FIREBASE_PROJECT_ID;
  const apiKey = import.meta.env.VITE_FIREBASE_API_KEY;
  const appId = import.meta.env.VITE_FIREBASE_APP_ID;
  if (!projectId || !apiKey || !appId) return null;

  return {
    apiKey,
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId,
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    appId,
  };
}

async function configFromHosting() {
  const res = await fetch("/__/firebase/init.json");
  if (!res.ok) return null;
  return res.json();
}

/**
 * ローカル: .env の VITE_* を使用
 * Firebase Hosting 本番: /__/firebase/init.json を自動利用
 */
export async function initFirebase() {
  const envConfig = configFromEnv();
  const config = envConfig ?? (await configFromHosting());

  if (!config?.projectId || !config?.apiKey) {
    throw new Error(
      "Firebase の Web 設定がありません。web/.env を設定するか、firebase deploy で Hosting にデプロイしてください。"
    );
  }

  const app = initializeApp(config);
  return getFirestore(app);
}
