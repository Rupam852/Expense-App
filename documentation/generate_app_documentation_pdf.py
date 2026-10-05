import os
import sys
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_header_footer(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_header_footer(self, page_count):
        if self._pageNumber == 1:
            # Skip header & footer on cover page
            return

        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#64748B"))

        # Header
        self.drawString(54, 842 - 36, "GROW EXPENSE — Official Technical & Product Documentation")
        self.setFont("Helvetica", 8)
        self.drawRightString(595 - 54, 842 - 36, "v3.5.0 | Dual Personal & Business Financial OS")
        
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, 842 - 42, 595 - 54, 842 - 42)

        # Footer
        self.line(54, 45, 595 - 54, 45)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawString(54, 32, "Confidential — For Internal & Distribution Usage")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(595 - 54, 32, page_str)
        self.restoreState()


def create_documentation_pdf(filename="documentation/Grow_Expense_App_Complete_Documentation.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=45,
        rightMargin=45,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    
    # Custom Brand Colors
    PRIMARY = colors.HexColor("#00D09C")
    PRIMARY_DARK = colors.HexColor("#009E75")
    SECONDARY = colors.HexColor("#0F172A")
    ACCENT_BLUE = colors.HexColor("#2563EB")
    ACCENT_GOLD = colors.HexColor("#D97706")
    TEXT_DARK = colors.HexColor("#1E293B")
    TEXT_MUTED = colors.HexColor("#64748B")
    BG_LIGHT = colors.HexColor("#F8FAFC")
    BG_CARD = colors.HexColor("#F1F5F9")
    BORDER_COLOR = colors.HexColor("#E2E8F0")

    # Custom Paragraph Styles
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=28,
        leading=34,
        textColor=SECONDARY,
        alignment=0,
        spaceAfter=8
    )

    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=13,
        leading=18,
        textColor=PRIMARY_DARK,
        alignment=0,
        spaceAfter=20
    )

    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=SECONDARY,
        spaceBefore=16,
        spaceAfter=10,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=PRIMARY_DARK,
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )

    h3_style = ParagraphStyle(
        'Heading3_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=SECONDARY,
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=TEXT_DARK,
        spaceAfter=6
    )

    body_bold = ParagraphStyle(
        'Body_Bold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=TEXT_DARK,
        leftIndent=14,
        firstLineIndent=-10,
        spaceAfter=3
    )

    callout_style = ParagraphStyle(
        'Callout_Text',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=TEXT_DARK
    )

    code_style = ParagraphStyle(
        'Code_Text',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=8,
        leading=10.5,
        textColor=colors.HexColor("#0F172A")
    )

    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=TEXT_DARK
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11.5,
        textColor=TEXT_DARK
    )

    table_header = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12,
        textColor=colors.white
    )

    story = []

    # ==========================================
    # COVER PAGE
    # ==========================================
    story.append(Spacer(1, 40))
    
    # App Badge
    badge_data = [[
        Paragraph("<font color='#009E75'><b>GROW EXPENSE</b></font> <font color='#64748B'>| ENTERPRISE SPECIFICATION</font>", table_cell)
    ]]
    badge_table = Table(badge_data, colWidths=[240])
    badge_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#DCFCE7")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#86EFAC")),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(badge_table)
    story.append(Spacer(1, 15))

    story.append(Paragraph("Grow Expense App", title_style))
    story.append(Paragraph("Complete Technical Architecture, Feature Blueprint & User Manual", subtitle_style))
    
    story.append(HRFlowable(width="100%", thickness=2, color=PRIMARY, spaceBefore=0, spaceAfter=20))

    # Meta Overview Box
    meta_data = [
        [
            Paragraph("<b>Project Name:</b>", body_bold), Paragraph("Grow Expense (Personal & Business Financial OS)", body_style),
            Paragraph("<b>Version:</b>", body_bold), Paragraph("3.5.0 (Release Build)", body_style)
        ],
        [
            Paragraph("<b>Framework:</b>", body_bold), Paragraph("Flutter 3.x / Dart 3.x", body_style),
            Paragraph("<b>Local DB:</b>", body_bold), Paragraph("SQLite (sqflite) Offline-First", body_style)
        ],
        [
            Paragraph("<b>Cloud Backend:</b>", body_bold), Paragraph("Supabase PostgreSQL & Realtime Auth", body_style),
            Paragraph("<b>AI Engine:</b>", body_bold), Paragraph("Google Gemini 2.5 Flash & NVIDIA LLaMA 3.3", body_style)
        ],
        [
            Paragraph("<b>Multi-Lingual:</b>", body_bold), Paragraph("8 Indian Languages + Hinglish Support", body_style),
            Paragraph("<b>Platforms:</b>", body_bold), Paragraph("Android (Universal & Split ABIs), iOS, Web", body_style)
        ],
    ]
    meta_table = Table(meta_data, colWidths=[95, 160, 90, 160])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BG_CARD),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 25))

    # Executive Summary Card
    exec_summary_text = """
    <b>Executive Overview:</b><br/>
    <b>Grow Expense</b> is a state-of-the-art financial management ecosystem designed specifically for individuals, freelancers, retail shopkeepers, and micro/small business owners. Unlike standard single-purpose expense trackers, Grow Expense is engineered with a <b>Dual-Engine Architecture</b> that allows users to toggle instantly between <b>Personal Mode</b> (expense logging, visual budget analytics, recurring subscriptions, SMS parsers, predictive forecasting) and <b>Business Mode</b> (GST/Non-GST invoicing, inventory management with barcode/QR generation, customer/supplier Khata ledger, automated payment reminders via WhatsApp, and daily P&L statements).
    <br/><br/>
    Built with a robust <b>Offline-First approach</b>, data is instantaneously accessible and persisted locally in SQLite, and asynchronously synchronized with Supabase Cloud with automatic conflict resolution, zero data loss on logout/login, and military-grade biometric protection.
    """
    exec_table = Table([[Paragraph(exec_summary_text, callout_style)]], colWidths=[505])
    exec_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F0FDF4")),
        ('BOX', (0,0), (-1,-1), 1.2, PRIMARY),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('RIGHTPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(exec_table)

    story.append(PageBreak())

    # ==========================================
    # TABLE OF CONTENTS
    # ==========================================
    story.append(Paragraph("Table of Contents", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=12))

    toc_items = [
        ("1. System Architecture & Core Technology Stack", "3"),
        ("2. Dual-Engine Operating System (Personal vs. Business)", "4"),
        ("3. Personal Finance & Wealth Modules", "5"),
        ("4. Business Management, Invoicing & Khata Ledger", "6"),
        ("5. Mandi & Financial Calculator Hub (Unit Rates & Voice)", "7"),
        ("6. Autonomous AI CFO & Intelligent Financial Advisor", "8"),
        ("7. Multi-Lingual Regional Support Matrix (8 Languages)", "9"),
        ("8. Offline-First Synchronization & Conflict Resolution", "10"),
        ("9. Security, Biometrics, Export & Cloud Backup Lifecycle", "11"),
        ("10. Database Schema Specifications & Data Models", "12"),
        ("11. Setup, Environment Configuration & Build Instructions", "13"),
    ]

    toc_data = []
    for title, pg in toc_items:
        toc_data.append([Paragraph(f"<b>{title}</b>", body_style), Paragraph(f"<b>Page {pg}</b>", ParagraphStyle('R', parent=body_style, alignment=2))])

    toc_table = Table(toc_data, colWidths=[420, 85])
    toc_table.setStyle(TableStyle([
        ('LINEBELOW', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(toc_table)
    story.append(Spacer(1, 15))

    # ==========================================
    # SECTION 1: SYSTEM ARCHITECTURE
    # ==========================================
    story.append(Paragraph("1. System Architecture & Core Technology Stack", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Grow Expense is developed using a multi-tiered reactive architecture ensuring sub-16ms UI responsiveness (60-120 FPS high refresh rate support), minimal battery footprint, and zero latency local persistence.",
        body_style
    ))

    arch_data = [
        [Paragraph("Layer", table_header), Paragraph("Technology / Framework", table_header), Paragraph("Key Responsibilities & Capabilities", table_header)],
        [
            Paragraph("<b>Frontend UI</b>", table_cell_bold),
            Paragraph("Flutter 3.x / Dart 3.x", table_cell),
            Paragraph("Material Design 3 with custom glassmorphism, dynamic dark/light themes, Google Fonts (Outfit & Inter), responsive layouts for phones & tablets.", table_cell)
        ],
        [
            Paragraph("<b>State Management</b>", table_cell_bold),
            Paragraph("Provider & MultiProvider", table_cell),
            Paragraph("Granular reactive state isolation across UserProvider, ExpenseProvider, BusinessProvider, and ThemeController.", table_cell)
        ],
        [
            Paragraph("<b>Local Persistence</b>", table_cell_bold),
            Paragraph("SQLite (sqflite) + SharedPreferences", table_cell),
            Paragraph("Zero-latency offline read/write. Stores transactions, khata entries, invoices, inventory items, and cached AI chat histories.", table_cell)
        ],
        [
            Paragraph("<b>Cloud Backend</b>", table_cell_bold),
            Paragraph("Supabase (PostgreSQL 15)", table_cell),
            Paragraph("Realtime Auth, PostgreSQL Row-Level Security (RLS), incremental timestamp sync, soft-delete propagation, and automated cloud backup.", table_cell)
        ],
        [
            Paragraph("<b>AI Engines</b>", table_cell_bold),
            Paragraph("Google Gemini 2.5 Flash / NVIDIA LLaMA 3.3", table_cell),
            Paragraph("Context-aware financial analysis, autonomous ledger actions (add expense, split bills, set budgets), NLP prompt parsing.", table_cell)
        ],
        [
            Paragraph("<b>Hardware & Voice</b>", table_cell_bold),
            Paragraph("Speech-To-Text (STT) + Local Biometrics", table_cell),
            Paragraph("Multi-lingual voice expense recording, Sabji Mandi voice rate interpreter, Fingerprint / Face Unlock security.", table_cell)
        ],
    ]
    arch_table = Table(arch_data, colWidths=[90, 130, 285])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(arch_table)

    story.append(PageBreak())

    # ==========================================
    # SECTION 2: DUAL-ENGINE OPERATING SYSTEM
    # ==========================================
    story.append(Paragraph("2. Dual-Engine Operating System (Personal vs. Business)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "A cornerstone feature of Grow Expense is its seamless one-tap switching between <b>Personal Mode</b> and <b>Business Mode</b>. The entire application dynamically restructures its dashboard, navigation bars, reporting metrics, and AI prompts depending on the active mode.",
        body_style
    ))

    dual_data = [
        [Paragraph("Feature / Aspect", table_header), Paragraph("Personal Mode 🧑💼", table_header), Paragraph("Business Mode 🏢🛍️", table_header)],
        [
            Paragraph("<b>Primary Purpose</b>", table_cell_bold),
            Paragraph("Personal budgeting, expense tracking, daily spend limits, savings growth.", table_cell),
            Paragraph("Shopkeeper POS, daily sales turnover, invoice generation, customer credits (Udhar).", table_cell)
        ],
        [
            Paragraph("<b>Dashboard Metrics</b>", table_cell_bold),
            Paragraph("Total Spent, Monthly Budget Remaining, Category Breakdown, Recurring Bills.", table_cell),
            Paragraph("Total Revenue/Sales, Cost of Goods, Net Profit/Loss, Total To Receive & To Pay.", table_cell)
        ],
        [
            Paragraph("<b>Key Modules</b>", table_cell_bold),
            Paragraph("Budget Goals, Voice Expense Entry, SMS Parser, Mandi Unit Calculator, Analytics.", table_cell),
            Paragraph("Tax & Quotation Invoices, Khata Book, Product Catalog, Barcode Generator, POS.", table_cell)
        ],
        [
            Paragraph("<b>AI CFO Advisor</b>", table_cell_bold),
            Paragraph("Personalized saving tips, 50/30/20 budget analysis, overspending alerts.", table_cell),
            Paragraph("Business profit margins, tax liabilities, slow-moving inventory alerts, credit risk.", table_cell)
        ],
        [
            Paragraph("<b>Customer/Party CRM</b>", table_cell_bold),
            Paragraph("Friend debt splitting & informal loans.", table_cell),
            Paragraph("Full Customer & Supplier Ledger with WhatsApp payment reminder links & PDF bills.", table_cell)
        ],
    ]
    dual_table = Table(dual_data, colWidths=[110, 195, 200])
    dual_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(dual_table)
    story.append(Spacer(1, 15))

    # ==========================================
    # SECTION 3: PERSONAL FINANCE MODULES
    # ==========================================
    story.append(Paragraph("3. Personal Finance & Wealth Modules", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph("<b>1. Smart Multi-Category Expense & Income Tracker:</b>", h2_style))
    story.append(Paragraph("• Instant logging with predefined & customizable categories (Food, Travel, Bills, Shopping, Health, Salary, Investments). Supports multi-payment modes (UPI, Cash, Credit Card, Net Banking).", bullet_style))
    story.append(Paragraph("• Visual receipt and invoice photo attachments with full-screen zoom and cloud persistence.", bullet_style))
    story.append(Paragraph("• Tagging system (#vacation, #party, #medical) for cross-category granular audits.", bullet_style))

    story.append(Paragraph("<b>2. Automated SMS Financial Parser (Offline NLP):</b>", h2_style))
    story.append(Paragraph("• Intelligent regex engine parses bank transaction SMS messages (HDFC, SBI, ICICI, Axis, Paytm, GPay, PhonePe) securely on-device without sharing SMS contents to external servers.", bullet_style))
    story.append(Paragraph("• One-tap approval to convert detected debits and credits into verified ledger entries.", bullet_style))

    story.append(Paragraph("<b>3. Visual Budgeting & Spending Prediction:</b>", h2_style))
    story.append(Paragraph("• Category-specific and monthly aggregate budget caps with real-time progress bars (Green < 70%, Amber 70-90%, Red > 90%).", bullet_style))
    story.append(Paragraph("• Machine learning linear regression prediction estimates end-of-month spending based on current burn rate.", bullet_style))

    story.append(Paragraph("<b>4. Recurring Subscriptions & Utility Reminders:</b>", h2_style))
    story.append(Paragraph("• Automatic scheduling for rent, electricity, Netflix, SIPs, and insurance premiums with notification alarms.", bullet_style))

    story.append(PageBreak())

    # ==========================================
    # SECTION 4: BUSINESS MANAGEMENT & INVOICING
    # ==========================================
    story.append(Paragraph("4. Business Management, Invoicing & Khata Ledger", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph("<b>1. Professional GST & Non-GST Invoicing Engine:</b>", h2_style))
    story.append(Paragraph("• Create, customize, and print beautiful PDF invoices, estimates/quotations, and delivery challans.", bullet_style))
    story.append(Paragraph("• Configurable GST rates (0%, 5%, 12%, 18%, 28%), IGST/CGST/SGST splitting, and HSN/SAC codes.", bullet_style))
    story.append(Paragraph("• Include business logo, signature, bank UPI QR code for instant customer payment, and terms & conditions.", bullet_style))
    story.append(Paragraph("• Direct 1-tap WhatsApp sharing with formatted PDF documents and auto-generated message text.", bullet_style))

    story.append(Paragraph("<b>2. Digital Khata Book (Customer & Supplier Credit Ledger):</b>", h2_style))
    story.append(Paragraph("• Complete replacement for paper udhar books. Track 'Maine Diye' (Gave/Credit) and 'Maine Liye' (Got/Debit).", bullet_style))
    story.append(Paragraph("• Free WhatsApp payment reminder integration with customizable regional language greetings and UPI payment links.", bullet_style))
    story.append(Paragraph("• Comprehensive party statement PDF generation with date-range filters and running balance calculations.", bullet_style))

    story.append(Paragraph("<b>3. Inventory & Barcode/QR Label Generator:</b>", h2_style))
    story.append(Paragraph("• Product catalog management with SKU, cost price, selling price, low stock thresholds, and unit types.", bullet_style))
    story.append(Paragraph("• Built-in printable barcode and QR label generator with custom sheet layouts (A4 24-up, 40-up, thermal rolls).", bullet_style))
    story.append(Paragraph("• Camera-based barcode scanner for rapid point-of-sale checkout and stock deduction.", bullet_style))

    story.append(Spacer(1, 10))

    # ==========================================
    # SECTION 5: MANDI & FINANCIAL CALCULATOR HUB
    # ==========================================
    story.append(Paragraph("5. Mandi & Financial Calculator Hub", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Grow Expense includes a specialized 5-in-1 financial calculator suite designed for Indian markets, vegetable/grocery mandi traders, and everyday financial calculations:",
        body_style
    ))

    mandi_calc_data = [
        [Paragraph("Calculator Tool", table_header), Paragraph("Description & Capabilities", table_header), Paragraph("Voice & Regional Support", table_header)],
        [
            Paragraph("<b>Sabji Mandi Unit Rate Calculator</b>", table_cell_bold),
            Paragraph("Computes exact rates for awkward weights (e.g., 250g, 500g, 1.5kg, 3.75kg based on ₹/kg or ₹/quintal). Instant budget-to-weight reverse calculation.", table_cell),
            Paragraph("AI Voice input in Hindi, Bengali, Marathi, Gujarati, Tamil, Telugu, Kannada & English.", table_cell)
        ],
        [
            Paragraph("<b>Loan & EMI Calculator</b>", table_cell_bold),
            Paragraph("Calculates monthly EMI, total interest, and full repayment amortization schedule for Home, Car, and Personal Loans.", table_cell),
            Paragraph("Interactive sliders + direct tap-to-type numerical input with instant breakdown pie chart.", table_cell)
        ],
        [
            Paragraph("<b>GST Tax Calculator</b>", table_cell_bold),
            Paragraph("1-tap Add GST (+) or Remove GST (-) for all standard Indian tax slabs (3%, 5%, 12%, 18%, 28%).", table_cell),
            Paragraph("Shows original amount, GST component, and net total with quick-copy clipboard button.", table_cell)
        ],
        [
            Paragraph("<b>Discount & Sale Calculator</b>", table_cell_bold),
            Paragraph("Calculates discounted price, percentage saved, and multi-tier promotional discounts.", table_cell),
            Paragraph("Instant calculation with history logging.", table_cell)
        ],
        [
            Paragraph("<b>SIP & Wealth Compounder</b>", table_cell_bold),
            Paragraph("Projects mutual fund SIP growth, total invested amount, and estimated future wealth.", table_cell),
            Paragraph("Visual wealth vs invested capital comparison chart.", table_cell)
        ],
    ]
    calc_table = Table(mandi_calc_data, colWidths=[120, 240, 145])
    calc_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(calc_table)

    story.append(PageBreak())

    # ==========================================
    # SECTION 6: AUTONOMOUS AI CFO & ADVISOR
    # ==========================================
    story.append(Paragraph("6. Autonomous AI CFO & Intelligent Financial Advisor", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Powered by Google Gemini 2.5 and NVIDIA LLaMA 3.3, <b>Grow Expense AI</b> acts as a personalized Virtual Chief Financial Officer with real-time database action capabilities.",
        body_style
    ))

    ai_features_text = """
    <b>Key AI Capabilities & Autonomous Action Engine:</b><br/>
    • <b>Live Financial Ledger Awareness:</b> Automatically injects real-time financial snapshots (current month's spend, top categories, profit margins, outstanding receivables) into the prompt context without exposing PII.<br/>
    • <b>Autonomous Action Execution:</b> When the user types or speaks natural language commands (e.g. <i>'Add ₹500 for petrol'</i>, <i>'Set food budget to ₹6,000'</i>, <i>'Split ₹1,200 dinner with Rahul'</i>), the AI generates an interactive Action Proposal Card that users can execute with 1 tap directly into SQLite.<br/>
    • <b>Multi-Session Chat Architecture:</b> ChatGPT-style session drawer allowing users to create new topics, rename sessions, search chat histories, and clear cache.<br/>
    • <b>Dual Model Redundancy & Hybrid Key System:</b> Users can choose zero-config server default AI or supply their own custom Gemini/NVIDIA API keys with seamless automated fallback if one service experiences rate limits.
    """
    ai_box = Table([[Paragraph(ai_features_text, callout_style)]], colWidths=[505])
    ai_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EFF6FF")),
        ('BOX', (0,0), (-1,-1), 1, ACCENT_BLUE),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(ai_box)
    story.append(Spacer(1, 15))

    # ==========================================
    # SECTION 7: MULTI-LINGUAL REGIONAL MATRIX
    # ==========================================
    story.append(Paragraph("7. Multi-Lingual Regional Support Matrix (8 Languages)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Grow Expense provides native localized UI strings, voice recognition locales, notification templates, and AI prompt formatting across 8 major Indian languages:",
        body_style
    ))

    lang_data = [
        [Paragraph("Language", table_header), Paragraph("Code", table_header), Paragraph("Native Script", table_header), Paragraph("Voice STT Locale", table_header), Paragraph("AI & Calculator Synchronization", table_header)],
        [Paragraph("<b>English</b>", table_cell_bold), Paragraph("en", table_cell), Paragraph("English", table_cell), Paragraph("en_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Hindi</b>", table_cell_bold), Paragraph("hi", table_cell), Paragraph("हिन्दी", table_cell), Paragraph("hi_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Bengali</b>", table_cell_bold), Paragraph("bn", table_cell), Paragraph("বাংলা", table_cell), Paragraph("bn_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Marathi</b>", table_cell_bold), Paragraph("mr", table_cell), Paragraph("मराठी", table_cell), Paragraph("mr_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Gujarati</b>", table_cell_bold), Paragraph("gu", table_cell), Paragraph("ગુજરાતી", table_cell), Paragraph("gu_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Tamil</b>", table_cell_bold), Paragraph("ta", table_cell), Paragraph("தமிழ்", table_cell), Paragraph("ta_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Telugu</b>", table_cell_bold), Paragraph("te", table_cell), Paragraph("తెలుగు", table_cell), Paragraph("te_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Kannada</b>", table_cell_bold), Paragraph("kn", table_cell), Paragraph("ಕನ್ನಡ", table_cell), Paragraph("kn_IN", table_cell), Paragraph("Full UI, Prompts, Voice, Notifications", table_cell)],
        [Paragraph("<b>Hinglish</b>", table_cell_bold), Paragraph("hinglish", table_cell), Paragraph("Colloquial Mix", table_cell), Paragraph("en_IN / hi_IN", table_cell), Paragraph("Conversational Romanized Hindi Prompts", table_cell)],
    ]
    lang_table = Table(lang_data, colWidths=[75, 40, 75, 90, 225])
    lang_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(lang_table)

    story.append(PageBreak())

    # ==========================================
    # SECTION 8: OFFLINE-FIRST SYNCHRONIZATION
    # ==========================================
    story.append(Paragraph("8. Offline-First Synchronization & Conflict Resolution", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Grow Expense utilizes an advanced bidirectional synchronization engine ensuring 100% offline availability with instant cloud consistency upon internet reconnection:",
        body_style
    ))

    story.append(Paragraph("<b>1. Incremental Timestamp Sync & Soft Deletes:</b>", h2_style))
    story.append(Paragraph("• Every table contains `updated_at` (ISO8601 UTC) and `is_deleted` (0 or 1).", bullet_style))
    story.append(Paragraph("• Deletions are soft-deleted locally and pushed to Supabase to guarantee cross-device consistency without leaving orphan records.", bullet_style))

    story.append(Paragraph("<b>2. Zero Data Loss Authentication Lifecycle:</b>", h2_style))
    story.append(Paragraph("• <b>Account Logout:</b> Safely triggers an immediate push of any pending offline records, followed by a clean wipe of local SQLite caches to prevent account data leakage between multiple users on the same device.", bullet_style))
    story.append(Paragraph("• <b>Fresh Login / Reinstall:</b> Automatically fetches the user's complete cloud ledger (expenses, budgets, khata entries, business sales, invoices) and populates SQLite seamlessly within seconds.", bullet_style))

    story.append(Paragraph("<b>3. Conflict Resolution Strategy:</b>", h2_style))
    story.append(Paragraph("• Last-Write-Wins (LWW) based on server-side PostgreSQL timestamp verification.", bullet_style))
    story.append(Paragraph("• UUIDv4 primary keys prevent ID collisions across offline client creations.", bullet_style))

    story.append(Spacer(1, 10))

    # ==========================================
    # SECTION 9: SECURITY, EXPORT & BACKUPS
    # ==========================================
    story.append(Paragraph("9. Security, Biometrics, Export & Cloud Backup Lifecycle", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph("<b>1. Enterprise Security & Privacy:</b>", h2_style))
    story.append(Paragraph("• Biometric authentication (Fingerprint / Face ID) with auto-lock timer.", bullet_style))
    story.append(Paragraph("• Supabase Row-Level Security (RLS) ensures users can only read/write their own authenticated records.", bullet_style))
    story.append(Paragraph("• API Keys stored strictly in encrypted SharedPreferences on-device.", bullet_style))

    story.append(Paragraph("<b>2. Export & Reporting:</b>", h2_style))
    story.append(Paragraph("• <b>PDF Financial Statements:</b> Clean, formatted summary with category distribution charts and transaction line items.", bullet_style))
    story.append(Paragraph("• <b>Excel / CSV Export:</b> Raw ledger export for tax auditors and Chartered Accountants.", bullet_style))
    story.append(Paragraph("• <b>Full JSON Backup & Restore:</b> Offline scope-selectable encrypted backup file.", bullet_style))

    story.append(PageBreak())

    # ==========================================
    # SECTION 10: DATABASE SCHEMA SPECIFICATIONS
    # ==========================================
    story.append(Paragraph("10. Database Schema Specifications & Data Models", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    story.append(Paragraph(
        "Below is the core relational schema implemented across local SQLite and Supabase PostgreSQL:",
        body_style
    ))

    schema_data = [
        [Paragraph("Table Name", table_header), Paragraph("Primary Columns", table_header), Paragraph("Description & Relationships", table_header)],
        [
            Paragraph("<b>expenses</b>", table_cell_bold),
            Paragraph("id (UUID), title, amount, category, date, payment_mode, notes, is_recurring, user_id, is_deleted, updated_at", table_cell),
            Paragraph("Stores personal expenses with receipt links and recurring subscription flags.", table_cell)
        ],
        [
            Paragraph("<b>budgets</b>", table_cell_bold),
            Paragraph("id (UUID), category, amount_limit, month_year, alert_threshold, user_id, is_deleted, updated_at", table_cell),
            Paragraph("Monthly budget caps per category for personal financial guardrails.", table_cell)
        ],
        [
            Paragraph("<b>business_sales</b>", table_cell_bold),
            Paragraph("id (UUID), invoice_no, customer_name, customer_phone, total_amount, tax_amount, discount, payment_status, date, user_id", table_cell),
            Paragraph("Business POS and invoicing transactions with tax & payment statuses.", table_cell)
        ],
        [
            Paragraph("<b>khata_entries</b>", table_cell_bold),
            Paragraph("id (UUID), party_name, party_phone, party_type (customer/supplier), entry_type (you_gave/you_got), amount, date, user_id", table_cell),
            Paragraph("Digital Udhar ledger recording receivables and payables per contact.", table_cell)
        ],
        [
            Paragraph("<b>inventory_products</b>", table_cell_bold),
            Paragraph("id (UUID), name, sku_barcode, purchase_price, selling_price, stock_quantity, unit_type, min_alert_qty, user_id", table_cell),
            Paragraph("Product catalog and stock management with barcode scanner integration.", table_cell)
        ],
        [
            Paragraph("<b>ai_chat_messages</b>", table_cell_bold),
            Paragraph("id (UUID), session_id, message_text, is_user, timestamp, action_intent_json, mode (personal/business)", table_cell),
            Paragraph("Multi-session AI chat conversation history with action intent persistence.", table_cell)
        ],
    ]
    schema_table = Table(schema_data, colWidths=[105, 230, 170])
    schema_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('INNERGRID', (0,0), (-1,-1), 0.5, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(schema_table)

    story.append(Spacer(1, 15))

    # ==========================================
    # SECTION 11: SETUP & BUILD INSTRUCTIONS
    # ==========================================
    story.append(Paragraph("11. Setup, Environment Configuration & Build Instructions", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=BORDER_COLOR, spaceBefore=0, spaceAfter=10))

    setup_text = """
    <b>1. Prerequisites:</b><br/>
    • Flutter SDK: 3.22.x or higher (Dart 3.4.x+)<br/>
    • Android Studio / VS Code with Flutter extensions<br/>
    • JDK 17 (Java Development Kit)<br/>
    • Android SDK Platform 34 (API Level 34)<br/><br/>
    <b>2. Environment & Secret Setup:</b><br/>
    Configure Supabase credentials in <code>frontend/lib/services/supabase_service.dart</code>:<br/>
    <code>SUPABASE_URL = 'https://[your-project-id].supabase.co'</code><br/>
    <code>SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1Ni...'</code><br/><br/>
    <b>3. Compiling Release Production APKs:</b><br/>
    To generate high-efficiency split APKs per architecture (ARM64, ARMv7, x86_64):<br/>
    <code>flutter clean && flutter pub get</code><br/>
    <code>flutter build apk --release --split-per-abi</code><br/><br/>
    <b>Output Artifacts:</b><br/>
    • <b>ARM64-v8a (Modern 64-bit phones):</b> <code>build/app/outputs/flutter-apk/app-arm64-v8a-release.apk</code><br/>
    • <b>ARMeabi-v7a (Older 32-bit phones):</b> <code>build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk</code><br/>
    • <b>x86_64 (Emulators / ChromeOS):</b> <code>build/app/outputs/flutter-apk/app-x86_64-release.apk</code>
    """
    setup_box = Table([[Paragraph(setup_text, callout_style)]], colWidths=[505])
    setup_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), BG_LIGHT),
        ('BOX', (0,0), (-1,-1), 1, BORDER_COLOR),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(setup_box)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Documentation successfully created: {filename}")

if __name__ == '__main__':
    create_documentation_pdf()
