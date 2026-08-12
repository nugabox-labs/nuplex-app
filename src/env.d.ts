/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 개발 중 웹뷰가 볼 주소. 지정하지 않으면 운영 도메인을 쓴다. */
  readonly VITE_WEB_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
