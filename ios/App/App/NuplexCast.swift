import Foundation
import UIKit
import AVKit

/**
 TV 로 쏘기 — Plex Companion (iOS).

 근거와 함정은 전부 `docs/PLEX_CAST.md` 에 있다. 여기서는 그중 코드에 직접 영향을
 주는 것만 짧게 반복한다.

 - **플레이어와 같은 WiFi 에 있을 때만 된다.** Plex 가 광고하는 플레이어 주소는
   사설 IP 하나뿐이고 relay 주소가 없다. 그래서 `listTargets` 는 후보에 실제로
   닿아 보고 응답한 것만 돌려준다 — 목록에 뜨면 반드시 눌린다.
 - **`X-Plex-Target-Client-Identifier` 는 맨 뒤에 붙인다.** 중간에 두었을 때
   "header value and my client identifier don't match" 로 거절당했다. 값은 완전히
   같았다. 순서를 바꾸지 말 것.
 - **TV 에서 Plex 앱이 떠 있어야 한다.** Companion 서버가 그 앱 프로세스 안에 있다.
   깨울 방법이 없어서, 실패하면 웹이 안내 문구를 띄우도록 이유를 돌려준다.

 토큰은 **보관하지 않는다.** 매 호출마다 웹에서 받아서 쓰고 버린다.
 */
enum NuplexCast {

    /// 플레이어 확인·명령에 쓸 제한 시간. 같은 랜이라 넉넉하다.
    private static let timeout: TimeInterval = 2.5

    /// Plex 는 컨트롤러마다 증가하는 commandID 를 기대한다. 앱 생애 동안 이어진다.
    private static var commandSeq = 0
    private static let seqLock = NSLock()

    private static func nextCommandID() -> Int {
        seqLock.lock()
        defer { seqLock.unlock() }
        commandSeq += 1
        return commandSeq
    }

    /// 이 앱을 식별하는 컨트롤러 ID. 플레이어가 세션을 구분하는 데만 쓴다.
    private static let controllerID = "nuplex-shell-ios"

    // MARK: - 후보 확인

    /**
     웹이 준 후보 중 **지금 닿는 것만** 골라 돌려준다.

     후보는 웹이 `plex.tv` 에서 받아 넘긴다. 셸이 직접 `plex.tv` 를 부르지 않는 이유는
     계정 토큰을 셸에 두지 않기 위해서다 — 목록 조회는 서버 몫이다.

     전부 병렬로 찔러 보고 응답한 것만 남긴다. 하나가 느려도 나머지를 붙잡지 않는다.
     */
    static func listTargets(
        candidates: [[String: Any]],
        token: String?,
        respond: @escaping (Any?) -> Void
    ) {
        guard let token, !token.isEmpty, !candidates.isEmpty else {
            respond(["targets": []])
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var reachable: [[String: Any]] = []

        for candidate in candidates {
            guard let id = candidate["id"] as? String, !id.isEmpty,
                  let uri = candidate["uri"] as? String,
                  let url = URL(string: "\(uri)/resources?X-Plex-Token=\(token)")
            else { continue }

            group.enter()
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            URLSession.shared.dataTask(with: request) { data, response, _ in
                defer { group.leave() }

                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let data, let body = String(data: data, encoding: .utf8),
                      body.contains("<Player")
                else { return }

                // 플레이어가 스스로 보고하는 ID 가 진짜다. plex.tv 등록값과 다를 수 있다.
                let selfReported = machineIdentifier(inResourcesXML: body) ?? id

                lock.lock()
                reachable.append([
                    "id": selfReported,
                    "name": candidate["name"] as? String ?? "TV",
                    "uri": uri,
                ])
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) {
            NSLog("[Nuplex] 캐스트 후보 \(candidates.count)개 중 \(reachable.count)개가 닿습니다.")
            respond(["targets": reachable])
        }
    }

    /// `<Player machineIdentifier="..."` 에서 값만 뽑는다. 응답이 작아 정규식으로 충분하다.
    private static func machineIdentifier(inResourcesXML xml: String) -> String? {
        guard let range = xml.range(of: "machineIdentifier=\"") else { return nil }
        let rest = xml[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let value = String(rest[..<end])
        return value.isEmpty ? nil : value
    }

    // MARK: - 재생 명령

    /**
     플레이어에 재생을 시킨다.

     형식은 실기기로 검증한 것이다(`docs/PLEX_CAST.md` §6). **파라미터 순서를 지킬 것** —
     대상 식별자가 마지막이어야 한다.
     */
    static func play(args: [String: Any], respond: @escaping (Any?) -> Void) {
        guard let uri = args["uri"] as? String,
              let targetID = args["targetId"] as? String, !targetID.isEmpty,
              let token = args["token"] as? String, !token.isEmpty,
              let machineIdentifier = args["machineIdentifier"] as? String, !machineIdentifier.isEmpty,
              let ratingKey = args["ratingKey"] as? String, !ratingKey.isEmpty
        else {
            respond(["ok": false, "error": "missing-params"])
            return
        }

        let address = args["serverAddress"] as? String ?? ""
        let port = args["serverPort"] as? Int ?? 443
        let proto = args["serverProtocol"] as? String ?? "https"
        let offset = args["offset"] as? Int ?? 0

        let metadataKey = "/library/metadata/\(ratingKey)"
        guard let encodedKey = metadataKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else {
            respond(["ok": false, "error": "bad-rating-key"])
            return
        }

        // 순서가 곧 사양이다 — 대상 식별자를 맨 뒤에 둔다.
        var query = "address=\(address)&port=\(port)&protocol=\(proto)"
        query += "&machineIdentifier=\(machineIdentifier)"
        query += "&key=\(encodedKey)"
        query += "&offset=\(offset)"
        query += "&commandID=\(nextCommandID())"
        query += "&X-Plex-Client-Identifier=\(controllerID)"
        query += "&X-Plex-Token=\(token)"
        query += "&X-Plex-Target-Client-Identifier=\(targetID)"

        guard let url = URL(string: "\(uri)/player/playback/playMedia?\(query)") else {
            respond(["ok": false, "error": "bad-url"])
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        // 헤더로도 함께 보낸다. 쿼리만으로 동작하는 것을 확인했지만, 플레이어 구현에
        // 따라 헤더만 보는 경우를 대비한 것이다. 둘이 같은 값이면 충돌하지 않는다.
        request.setValue(targetID, forHTTPHeaderField: "X-Plex-Target-Client-Identifier")
        request.setValue(controllerID, forHTTPHeaderField: "X-Plex-Client-Identifier")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                // 폰이 그 랜을 떠났거나 TV 가 꺼졌다.
                NSLog("[Nuplex] 캐스트 실패(연결): \(error.localizedDescription)")
                DispatchQueue.main.async { respond(["ok": false, "error": "unreachable"]) }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                NSLog("[Nuplex] 캐스트 성공: \(ratingKey) → \(targetID)")
                DispatchQueue.main.async { respond(["ok": true]) }
                return
            }

            // Plex 는 실패 이유를 본문에 적어 준다. 그대로 넘겨 웹이 안내하게 한다.
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            NSLog("[Nuplex] 캐스트 실패(\(status)): \(body.prefix(200))")
            DispatchQueue.main.async {
                respond(["ok": false, "error": "rejected", "status": status, "detail": String(body.prefix(300))])
            }
        }.resume()
    }

    // MARK: - AirPlay 피커

    /**
     시스템 AirPlay 피커를 띄운다.

     **지금은 반쪽이다.** `AVRoutePickerView` 는 "이 앱의 AV 재생을 어디로 보낼까" 를
     고르는 물건이라, 앱이 네이티브로 재생 중인 것이 없으면 골라도 아무 일이 일어나지
     않는다. 앱 안 재생("여기서 시청하기")이 붙는 2단계에서 온전해진다.

     화면 미러링은 제어 센터 전용이고 앱이 시작시키는 API 가 없다. 이 피커가 iOS 에서
     할 수 있는 전부다.
     */
    static func showRoutePicker(controller: UIViewController?, respond: @escaping (Any?) -> Void) {
        DispatchQueue.main.async {
            guard let host = controller?.view else {
                respond(["shown": false])
                return
            }

            // 피커는 사용자가 직접 누른 것처럼 보여야 열린다. 보이지 않는 크기로 붙여
            // 두고 내부 버튼을 눌러 준 뒤 걷어낸다.
            let picker = AVRoutePickerView(frame: .zero)
            picker.isHidden = true
            host.addSubview(picker)

            let button = picker.subviews.compactMap { $0 as? UIButton }.first
            button?.sendActions(for: .touchUpInside)

            // 피커가 뜬 뒤에 걷어내야 한다. 즉시 지우면 시트가 같이 사라진다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { picker.removeFromSuperview() }

            respond(["shown": button != nil])
        }
    }
}
