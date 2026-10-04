// Table from Blockchain Commons URKit, BSD-2-Clause Plus Patent; see ScannerNotices.txt.
import Foundation

enum ScannerBytewords {
    static let table = Array("ableacidalsoapexaquaarchatomauntawayaxisbackbaldbarnbeltbetabiasbluebodybragbrewbulbbuzzcalmcashcatschefcityclawcodecolacookcostcruxcurlcuspcyandarkdatadaysdelidicedietdoordowndrawdropdrumdulldutyeacheasyechoedgeepicevenexamexiteyesfactfairfernfigsfilmfishfizzflapflewfluxfoxyfreefrogfuelfundgalagamegeargemsgiftgirlglowgoodgraygrimgurugushgyrohalfhanghardhawkheathelphighhillholyhopehornhutsicedideaidleinchinkyintoirisironitemjadejazzjoinjoltjowljudojugsjumpjunkjurykeepkenokeptkeyskickkilnkingkitekiwiknoblamblavalazyleaflegsliarlimplionlistlogoloudloveluaulucklungmainmanymathmazememomenumeowmildmintmissmonknailnavyneednewsnextnoonnotenumbobeyoboeomitonyxopenovalowlspaidpartpeckplaypluspoempoolposepuffpumapurrquadquizraceramprealredorichroadrockroofrubyruinrunsrustsafesagascarsetssilkskewslotsoapsolosongstubsurfswantacotasktaxitenttiedtimetinytoiltombtoystriptunatwinuglyundouniturgeuservastveryvetovialvibeviewvisavoidvowswallwandwarmwaspwavewaxywebswhatwhenwhizwolfworkyankyawnyellyogayurtzapszerozestzinczonezoom".utf8)
    static let lookup: [UInt16: UInt8] = {
        var result: [UInt16: UInt8] = [:]
        for index in 0..<256 {
            let first = UInt16(table[index * 4]) << 8
            let last = UInt16(table[index * 4 + 3])
            result[first | last] = UInt8(index)
        }
        return result
    }()
    static func decode(_ text: Substring) throws -> SecureBytes {
        guard text.utf8.count > 8, text.utf8.count <= 16384, text.utf8.count % 2 == 0 else { throw ScanDecodeError.invalid }
        let decoded = SecureBytes(capacity: text.utf8.count/2)
        defer { decoded.wipe() }
        var it = text.utf8.makeIterator()
        while let first = it.next(), let last = it.next() {
            let a = (65...90).contains(first) ? first+32 : first
            let b = (65...90).contains(last) ? last+32 : last
            guard let byte = lookup[UInt16(a) << 8 | UInt16(b)] else { throw ScanDecodeError.invalid }
            try decoded.append(byte)
        }
        return try decoded.withUnsafeBytes { bytes in
            let payload = UnsafeRawBufferPointer(rebasing: bytes.dropLast(4))
            guard ScanCRC32.checksum(payload) == KeyValidation.uint32(bytes, at: bytes.count-4) else { throw ScanDecodeError.invalid }
            return try ScanBytes.copy(payload)
        }
    }
}
