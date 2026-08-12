#!/usr/bin/env node
/**
 * Capacitor CLI wrapper.
 *
 * 이 머신에는 RVM이 GEM_HOME/GEM_PATH를 전역 export 하고 있어서,
 * Homebrew로 설치한 CocoaPods가 RVM(ruby 2.7.4)의 gem 경로를 보고 크래시한다.
 * `npx cap add ios` / `npx cap sync ios` 는 내부적으로 `pod install`을 호출하므로
 * 이 오염된 환경변수를 그대로 물려받는다.
 *
 * 사용자의 전역 셸 프로필(~/.zshrc)을 건드리면 다른 Ruby 프로젝트가 깨지므로,
 * 이 저장소의 Capacitor 명령에서만 해당 변수를 걷어낸다.
 * 자세한 내용: docs/TROUBLESHOOTING.md
 */
import { spawnSync } from 'node:child_process';

import { existsSync } from 'node:fs';

const env = { ...process.env };
for (const key of ['GEM_HOME', 'GEM_PATH', 'RUBYOPT', 'RUBYLIB', 'BUNDLE_GEMFILE']) {
  delete env[key];
}

/**
 * AGP 8.13 은 JDK 17+ 를 요구하지만 이 머신의 기본 JDK 는 11 이다.
 * Android Studio 번들 JBR(21)이 있으면 그것을 쓴다.
 * CI 처럼 적절한 JDK 가 이미 잡혀 있는 환경에서는 CAP_SKIP_JBR=1 로 끈다.
 */
const JBR = '/Applications/Android Studio.app/Contents/jbr/Contents/Home';
if (!env.CAP_SKIP_JBR && existsSync(JBR)) {
  env.JAVA_HOME = JBR;
}

const result = spawnSync('npx', ['cap', ...process.argv.slice(2)], {
  stdio: 'inherit',
  env,
});

process.exit(result.status ?? 1);
