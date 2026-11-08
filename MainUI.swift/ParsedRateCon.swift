//
//  ParsedRateCon.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 6/1/26.
//


//
//  RateConParserService.swift
//  MainUI.swift
//
//  Extracts load data and broker info from rate confirmation PDFs
//  using PDFKit text extraction + keyword pattern matching.
//

import Foundation
import PDFKit

// MARK: - Parsed Rate Con Data
struct ParsedRateCon {
    // Load fields
    var loadNumber:      String = ""
    //  Legacy single-pickup / single-delivery outputs — populated by the current parser
    var pickupLocation:  String = ""
    var pickupDate:      String = ""
    var pickupTime:      String = ""
    var deliveryLocation: String = ""
    var deliveryDate:    String = ""
    var deliveryTime:    String = ""
    //  Full stops output. If the parser can detect multiple pickups/deliveries it
    //  fills this in and callers prefer it over the legacy fields above.
    var stops:           [Stop] = []
    var rate:            String = ""
    var commodity:       String = ""
    var weight:          String = ""

    // Broker / client fields (for client profile)
    var brokerName:          String = ""
    var brokerAddress:        String = ""
    var brokerPhone:          String = ""
    var brokerEmail:          String = ""
    var brokerAccountingEmail: String = ""
    var brokerMC:             String = ""
    var brokerDOT:            String = ""
    var contactName:          String = ""
}

// MARK: - Rate Con Parser
class RateConParserService {

    static let shared = RateConParserService()

    // ✅ Main entry point — call with PDF data
    func parse(pdfData: Data) -> ParsedRateCon {
        guard let document = PDFDocument(data: pdfData) else {
            return ParsedRateCon()
        }

        // Extract all text from all pages
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                fullText += (page.string ?? "") + "\n"
            }
        }

        print("📄 Rate Con Text:\n\(fullText)")
        return extractFields(from: fullText)
    }

    // MARK: - Field Extraction
    private func extractFields(from text: String) -> ParsedRateCon {
        var result = ParsedRateCon()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // ── Load/Reference Number ──────────────────────────────
        // Capture must contain at least one digit to avoid matching brand words like "Loadsmart"
        result.loadNumber = extract(from: text, patterns: [
            #"(?:Shipment\s*number|Load\s*number|Order\s*number|Reference\s*number|Confirmation\s*number|Load\s*ID)[#\s:\.]*([A-Z0-9\-]*\d[A-Z0-9\-]*)"#,
            #"(?:Load|Order|Reference|Ref|PO|Confirmation|Conf|Shipment)[#\s:\.]+([A-Z0-9\-]*\d[A-Z0-9\-]*)"#,
            #"#\s*([A-Z0-9\-]*\d[A-Z0-9\-]{3,})"#
        ])

        // ── Rate ───────────────────────────────────────────────
        result.rate = extractRate(from: text)

        // ── Pickup Location ────────────────────────────────────
        result.pickupLocation = extractLocation(from: text, keywords: [
            "Pick", "Pickup", "Origin", "Ship From", "Loading", "PU"
        ])

        // ── Delivery Location ──────────────────────────────────
        result.deliveryLocation = extractLocation(from: text, keywords: [
            "Deliv", "Delivery", "Destination", "Ship To", "Drop", "Del"
        ])

        // ── Pickup Date & Time ─────────────────────────────────
        let puDateBlock = extractBlockAfterKeyword(text: text, keywords: ["Pick", "Pickup", "PU"], lines: 4)
        result.pickupDate = extractDate(from: puDateBlock)
        result.pickupTime = extractTime(from: puDateBlock)

        // ── Delivery Date & Time ───────────────────────────────
        let delDateBlock = extractBlockAfterKeyword(text: text, keywords: ["Deliv", "Delivery", "Drop"], lines: 4)
        result.deliveryDate = extractDate(from: delDateBlock)
        result.deliveryTime = extractTime(from: delDateBlock)

        // ── Commodity ──────────────────────────────────────────
        result.commodity = extract(from: text, patterns: [
            #"(?:Commodity|Cargo|Freight|Description|Load Type)[:\s]+([A-Za-z][^\n]{2,40})"#
        ])

        // ── Weight ─────────────────────────────────────────────
        result.weight = extract(from: text, patterns: [
            #"(\d[\d,]+)\s*(?:lbs|pounds|lb)\b"#,
            #"(?:Weight|Wt)[:\s]+(\d[\d,]+)"#
        ])

        // ── Broker Name ────────────────────────────────────────
        // Usually the first company name near the top
        result.brokerName = extractBrokerName(from: lines)

        // ── Broker Phone ───────────────────────────────────────
        result.brokerPhone = extract(from: text, patterns: [
            #"(?:\+1[\s\-]?)?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]\d{4}"#
        ])

        // ── Broker Email (main) ────────────────────────────────
        let emails = extractAllEmails(from: text)
        result.brokerEmail = emails.first ?? ""

        // ── Broker Accounting Email ────────────────────────────
        // Look for email near "accounting", "invoice", "billing", "payment"
        result.brokerAccountingEmail = extractAccountingEmail(from: text, allEmails: emails)

        // ── Broker MC / DOT ────────────────────────────────────
        result.brokerMC = extract(from: text, patterns: [
            #"MC[#\s:]*(\d{5,})"#,
            #"MC\s*No\.?\s*:?\s*(\d{5,})"#
        ])
        result.brokerDOT = extract(from: text, patterns: [
            #"DOT[#\s:]*(\d{5,})"#,
            #"USDOT[#\s:]*(\d{5,})"#
        ])

        // ── Contact Name ───────────────────────────────────────
        result.contactName = extract(from: text, patterns: [
            #"(?:Contact|Agent|Rep|Dispatcher)[:\s]+([A-Z][a-z]+ [A-Z][a-z]+)"#,
            #"(?:Booked by|Covered by)[:\s]+([A-Z][a-z]+ [A-Z][a-z]+)"#
        ])

        return result
    }

    // MARK: - Helpers

    private func extract(from text: String, patterns: [String]) -> String {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private func extractRate(from text: String) -> String {
        // Look for dollar amounts near rate keywords
        let patterns = [
            #"(?:Rate|Pay|Amount|Total)[:\s]*\$?([\d,]+(?:\.\d{2})?)"#,
            #"\$\s*([\d,]+(?:\.\d{2})?)"#
        ]
        let raw = extract(from: text, patterns: patterns)
        // Remove commas and return clean number
        return raw.replacingOccurrences(of: ",", with: "")
    }

    private func extractLocation(from text: String, keywords: [String]) -> String {
        for keyword in keywords {
            let pattern = "(?:\(keyword))[^:]*:[\\s]*([A-Za-z][^\\n]{5,60})"
            if let result = extractWithPattern(pattern, from: text), !result.isEmpty {
                return cleanLocation(result)
            }
        }
        return ""
    }

    private func extractWithPattern(_ pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespaces)
    }

    private func cleanLocation(_ raw: String) -> String {
        // Take first meaningful line, remove zip codes and extra info
        let line = raw.components(separatedBy: .newlines).first ?? raw
        return line.trimmingCharacters(in: .whitespaces)
    }

    private func extractBlockAfterKeyword(text: String, keywords: [String], lines: Int) -> String {
        let textLines = text.components(separatedBy: .newlines)
        for (i, line) in textLines.enumerated() {
            let lowerLine = line.lowercased()
            if keywords.contains(where: { lowerLine.contains($0.lowercased()) }) {
                let end = min(i + lines, textLines.count)
                return textLines[i..<end].joined(separator: " ")
            }
        }
        return ""
    }

    private func extractDate(from text: String) -> String {
        let patterns = [
            #"(\d{1,2}/\d{1,2}/\d{2,4})"#,
            #"(\d{1,2}-\d{1,2}-\d{2,4})"#,
            #"((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4})"#
        ]
        return extract(from: text, patterns: patterns)
    }

    private func extractTime(from text: String) -> String {
        // Strip years first so "2026" can't be mistaken for military time
        let withoutYears = text.replacingOccurrences(
            of: #"\b(19|20)\d{2}\b"#,
            with: "",
            options: .regularExpression
        )
        return extract(from: withoutYears, patterns: [
            #"(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)"#,
            #"\b([0-2]\d[0-5]\d)\s*(?:hrs|hours)?"#
        ])
    }

    private func extractAllEmails(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        ) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func extractAccountingEmail(from text: String, allEmails: [String]) -> String {
        let accountingKeywords = ["accounting", "invoice", "billing", "payment", "ar@", "ap@", "acct"]
        for email in allEmails {
            if accountingKeywords.contains(where: { email.lowercased().contains($0) }) {
                return email
            }
        }
        // Return second email if available (often accounting)
        if allEmails.count > 1 { return allEmails[1] }
        return ""
    }

    private func extractBrokerName(from lines: [String]) -> String {
        // Skip header noise and the carrier (= our company) — pick the first plausible broker line
        let bannedPrefixes = ["carrier:", "contact:", "driver:", "phone:", "fax:", "date:",
                              "order:", "order order:", "page", "rate confirmation",
                              "load confirmation", "*** load confirmation"]
        let companyHints = ["LLC", "INC", "CORP", "SERVICES", "LOGISTICS",
                            "FREIGHT", "TRANSPORT", "BROKERS", "TRANSPORTATION"]
        var fallback: String?
        for raw in lines.prefix(15) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            if bannedPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
            if lower.contains("carrier:") || lower.contains("driver:") { continue }
            if line.contains("@") || lower.contains("http") { continue }
            if line.filter({ $0.isNumber }).count >= 4 { continue }
            let words = line.split(separator: " ")
            guard words.count >= 2 && words.count <= 10 else { continue }
            let upper = line.uppercased()
            if companyHints.contains(where: { upper.contains($0) }) { return line }
            if fallback == nil { fallback = line }
        }
        return fallback ?? lines.first ?? ""
    }
}