import UIKit

// MARK: - Sample Flyer
/// Renders a concert flyer at runtime so "Try Sample Flyer" can run the real Vision OCR + inference
/// pipeline without photo permissions. The date is always ~3 weeks out so the result is a future event.
enum SampleFlyer {
    static func eventDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 21, to: calendar.startOfDay(for: now)) ?? now
    }

    static func render(now: Date = Date()) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let dateLine = dateFormatter.string(from: eventDate(from: now)).uppercased()

        return renderer.image { context in
            let cg = context.cgContext
            let colors = [
                UIColor(red: 5 / 255, green: 8 / 255, blue: 22 / 255, alpha: 1).cgColor,
                UIColor(red: 60 / 255, green: 20 / 255, blue: 90 / 255, alpha: 1).cgColor,
                UIColor(red: 120 / 255, green: 24 / 255, blue: 80 / 255, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }

            let lines: [(String, CGFloat, UIFont.Weight)] = [
                ("NEON SUNSET", 132, .black),
                ("ROOFTOP SESSION", 84, .heavy),
                (dateLine, 50, .bold),
                ("DOORS 7:00 PM", 56, .semibold),
                ("SHOW 8:30 PM", 56, .semibold),
                ("SKYBAR PENTHOUSE", 54, .bold),
                ("8440 SUNSET BLVD, WEST HOLLYWOOD, CA", 38, .medium),
                ("DJ KAI & FRIENDS · 21+", 38, .medium)
            ]

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            var y: CGFloat = 150
            for (text, pointSize, weight) in lines {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: pointSize, weight: weight),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let rect = CGRect(x: 60, y: y, width: size.width - 120, height: pointSize * 1.3)
                (text as NSString).draw(in: rect, withAttributes: attributes)
                y += pointSize * 1.3 + (pointSize > 80 ? 30 : 40)
            }
        }
    }
}
