/**
 * semver 비교. 셸이 쓰는 범위는 "MAJOR.MINOR.PATCH 세 숫자" 뿐이라 라이브러리를
 * 넣지 않는다. 프리릴리스 태그(-beta.1)는 숫자 부분만 보고 무시한다.
 */
function parse(version: string): [number, number, number] {
  const core = version.trim().split(/[-+]/)[0] ?? '';
  const parts = core.split('.').map((p) => Number.parseInt(p, 10));
  return [parts[0] ?? 0, parts[1] ?? 0, parts[2] ?? 0];
}

/** a < b 이면 음수, 같으면 0, a > b 이면 양수. */
export function compareVersions(a: string, b: string): number {
  const left = parse(a);
  const right = parse(b);
  for (let i = 0; i < 3; i += 1) {
    const diff = (left[i] ?? 0) - (right[i] ?? 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

export function isBelow(current: string, required: string): boolean {
  return compareVersions(current, required) < 0;
}
