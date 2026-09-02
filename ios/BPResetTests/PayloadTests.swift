import XCTest
@testable import BPReset

/// The wire shape sent to `ingest_observations` and `enrol_patient`, and the response shape
/// read back. These are the contracts the deployed v0.2 schema enforces.
final class PayloadTests: XCTestCase {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func queued(tz: String?, offset: Int?) -> QueuedReading {
        QueuedReading(
            itemId: ULID.generate(),
            hkUuid: "CORR-1", systolicUuid: "SYS-1", diastolicUuid: "DIA-1",
            enrolmentRef: "enrolment",
            systolic: 121, diastolic: 79,
            takenAt: Date(timeIntervalSince1970: 1_720_000_000),
            tzIdentifier: tz, tzOffsetMinutes: offset,
            sourceBundleId: "jp.co.omron.example", sourceName: "OMRON connect", deviceModel: "HEM-example",
            receivedAt: Date(timeIntervalSince1970: 1_720_000_100))
    }

    // The defect found live on 2 Sep: a nil optional must be sent as an explicit null,
    // because PostgREST resolves an RPC by the named parameters present in the body.
    func testEnrolParamsSendsNullNotAbsence() throws {
        let body = try json(EnrolParams(p_display_name: nil, p_adult_attested: true))
        XCTAssertTrue(body.keys.contains("p_display_name"), "the key must be present")
        XCTAssertTrue(body["p_display_name"] is NSNull)
        XCTAssertEqual(body["p_adult_attested"] as? Bool, true)
    }

    func testHealthKitPayloadShape() throws {
        let payload = PayloadBuilder.healthKit([queued(tz: "Australia/Sydney", offset: 600)])
        let body = try json(payload)
        XCTAssertEqual(body["source_type"] as? String, "healthkit")
        let obs = try XCTUnwrap((body["observations"] as? [[String: Any]])?.first)
        XCTAssertEqual(obs["source_uuid"] as? String, "CORR-1", "the correlation UUID is the idempotency key")
        XCTAssertEqual(obs["code"] as? String, LOINC.bpPanel)
        XCTAssertEqual(obs["source_system"] as? String, "jp.co.omron.example")
        XCTAssertEqual(obs["source_name"] as? String, "OMRON connect")
        XCTAssertEqual(obs["source_user_entered"] as? Bool, false)
        XCTAssertEqual(obs["effective_tz"] as? String, "Australia/Sydney")
        XCTAssertEqual(obs["effective_offset_minutes"] as? Int, 600)
        XCTAssertNil(obs["body_site_code"], "HealthKit carries no arm; nothing is invented")
        let components = try XCTUnwrap(obs["components"] as? [[String: Any]])
        XCTAssertEqual(components.map { $0["code"] as? String }, [LOINC.systolic, LOINC.diastolic])
        XCTAssertEqual(components.map { $0["source_uuid"] as? String }, ["SYS-1", "DIA-1"], "child sample UUIDs satisfy observation_component.source_uuid")
        XCTAssertTrue(components.allSatisfy { ($0["value_unit"] as? String) == LOINC.unit })
    }

    func testHealthKitPayloadNeverFabricatesATimezone() throws {
        let body = try json(PayloadBuilder.healthKit([queued(tz: nil, offset: nil)]))
        let obs = try XCTUnwrap((body["observations"] as? [[String: Any]])?.first)
        XCTAssertTrue(obs["effective_tz"] == nil || obs["effective_tz"] is NSNull, "absent metadata is sent as nothing; the server default is the server's decision (Q7)")
        XCTAssertTrue(obs["effective_offset_minutes"] == nil || obs["effective_offset_minutes"] is NSNull)
    }

    func testManualPayloadShape() throws {
        let body = try json(PayloadBuilder.manual(systolic: 118, diastolic: 76, takenAt: Date(), arm: "right"))
        XCTAssertEqual(body["source_type"] as? String, "manual")
        let obs = try XCTUnwrap((body["observations"] as? [[String: Any]])?.first)
        XCTAssertEqual(obs["source_user_entered"] as? Bool, true)
        XCTAssertEqual(obs["body_site_code"] as? String, SNOMEDBodySite.rightArm)
        XCTAssertEqual((obs["context"] as? [String: Any])?["arm"] as? String, "right")
        XCTAssertEqual(obs["effective_tz"] as? String, TimeZone.current.identifier, "manual entry happened on this phone, so its zone is known")
        XCTAssertNotNil(obs["source_uuid"] as? String)
    }

    func testIngestResponseDecodes() throws {
        let raw = """
        {"inserted":1,"duplicates":2,"soft_deleted":0,
         "rejected":[{"source_uuid":"X","reason":"VALUE_OUT_OF_BOUNDS","detail":"redacted"}]}
        """
        let response = try JSONDecoder().decode(IngestResponse.self, from: Data(raw.utf8))
        XCTAssertEqual(response.inserted, 1)
        XCTAssertEqual(response.duplicates, 2)
        XCTAssertEqual(response.rejected.first?.reason, .valueOutOfBounds)
    }

    func testConsentHashIsStableAndHex() {
        let a = ConsentHash.current()
        XCTAssertEqual(a, ConsentHash.current())
        XCTAssertEqual(a.count, 64)
        XCTAssertTrue(a.allSatisfy { $0.isHexDigit })
    }
}
