import Foundation
import CoreGraphics
@main struct Tests {
 static func main() async throws {
  var count = 0
  func check(_ condition: @autoclosure () -> Bool, _ name: String) { precondition(condition(),name); count += 1; print("PASS \(name)") }
  let p = Provider.presets[0]
  let r = try Optimizer.request(provider:p,key:"synthetic-test-key",system:"edit",text:"sample")
  check(r.url?.absoluteString == "https://api.deepseek.com/v1/chat/completions","OpenAI path")
  check(r.value(forHTTPHeaderField:"Authorization") == "Bearer synthetic-test-key","OpenAI auth")
  let body = try JSONSerialization.jsonObject(with:r.httpBody!) as! [String:Any]
  check(body["stream"] as? Bool == false,"non-stream response")
  for (wire,json,want) in [(Provider.Wire.openAI,"{\"choices\":[{\"message\":{\"content\":\"hello\"}}]}","hello"),(.anthropic,"{\"content\":[{\"type\":\"text\",\"text\":\"hello\"}]}","hello"),(.gemini,"{\"candidates\":[{\"content\":{\"parts\":[{\"thought\":true,\"text\":\"private\"},{\"text\":\"hello\"}]}}]}","hello")] {
   let result = try Optimizer.parse(data:Data(json.utf8),status:200,wire:wire); check(result == want,"\(wire) parsing")
  }
  for status in [401,403,404,429,500] {
   do { _ = try Optimizer.parse(data:Data(),status:status,wire:.openAI); fatalError("accepted HTTP failure") } catch { check(error.localizedDescription.contains("\(status)"),"HTTP \(status)") }
  }
  do { _ = try Optimizer.parse(data:Data("{}".utf8),status:200,wire:.openAI); fatalError("accepted empty output") } catch { count += 1; print("PASS empty output rejected") }
  for bad in ["http://example.com", "https://example.com?api_key=abc", "https://a:b@example.com"] {
   var q = p; q.baseURL = bad
   do { _ = try Optimizer.request(provider:q,key:"x",system:"x",text:"x"); fatalError("accepted bad URL") } catch { count += 1; print("PASS unsafe URL rejected") }
  }
  var a = Provider.presets[4]; a.model = "test-model"
  let ar = try Optimizer.request(provider:a,key:"test",system:"x",text:"x")
  check(ar.url?.path == "/v1/messages", "Anthropic path")
  check(ar.value(forHTTPHeaderField:"x-api-key") == "test", "Anthropic auth")
  var g = Provider.presets[5]; g.model = "test-model"
  let gr = try Optimizer.request(provider:g,key:"test",system:"x",text:"x")
  check(gr.url?.path == "/v1beta/models/test-model:generateContent", "Gemini path")
  check(gr.url?.query == nil && gr.value(forHTTPHeaderField:"x-goog-api-key") == "test", "Gemini key in header")
  let prefs = Preferences(); let roundTrip = try JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(prefs)); check(roundTrip.selectedProvider == prefs.selectedProvider,"preferences round trip")
  let display = CGRect(x:0,y:0,width:1440,height:900)
  for center in [CGPoint(x:60,y:60),CGPoint(x:1380,y:60),CGPoint(x:60,y:840),CGPoint(x:1380,y:840)] {
   let compact = Placement.frame(center:center,size:CGSize(width:112,height:54),visible:display)
   for size in [CGSize(width:595,height:82),CGSize(width:595,height:362),CGSize(width:463,height:526)] {
    let expanded = Placement.frame(center:center,size:size,visible:display)
    check(display.contains(expanded),"expanded panel fits screen")
    let restored = Placement.frame(center:center,size:compact.size,visible:display)
    check(restored == compact,"collapse restores capsule anchor near edge")
   }
  }
  let secondDisplay = CGRect(x:-1440,y:100,width:1440,height:900)
  let secondFrame = Placement.frame(center:CGPoint(x:-60,y:170),size:CGSize(width:595,height:362),visible:secondDisplay)
  check(secondDisplay.contains(secondFrame),"negative display coordinates")
  for origin in [CGPoint(x:0,y:0),CGPoint(x:1308,y:0),CGPoint(x:0,y:840),CGPoint(x:1308,y:840)] {
   let capsule = CGRect(origin:origin,size:CGSize(width:132,height:60))
   let before = capsule
   let detail = Placement.detail(capsule:capsule,size:CGSize(width:595,height:362),visible:display)
   check(display.contains(detail),"separate detail fits display")
   check(capsule == before,"capsule unchanged by detail placement")
   check(!detail.intersects(capsule),"detail does not displace or overlap capsule")
  }
  print("\(count) checks passed. No live API request was made.")
 }
}
