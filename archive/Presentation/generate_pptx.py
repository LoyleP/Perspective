#!/usr/bin/env python3
"""
Generates Perspective presentation PowerPoint deck.
Requires: pip install python-pptx
"""

from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

def create_presentation():
    prs = Presentation()
    prs.slide_width = Inches(16)
    prs.slide_height = Inches(9)

    # Color scheme (from PoliticalLean.swift)
    RED_LEFT = RGBColor(192, 57, 43)      # gauche
    GRAY_CENTER = RGBColor(181, 181, 181) # centre
    BLUE_RIGHT = RGBColor(46, 74, 139)    # droite
    DARK_BG = RGBColor(18, 18, 18)
    WHITE = RGBColor(255, 255, 255)

    # Slide 1: Hook + Problem
    slide1 = prs.slides.add_slide(prs.slide_layouts[6])  # Blank layout
    background = slide1.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title1 = slide1.shapes.add_textbox(Inches(1), Inches(2), Inches(14), Inches(2))
    tf1 = title1.text_frame
    tf1.text = "Same Story. Opposite Headlines."
    p1 = tf1.paragraphs[0]
    p1.font.size = Pt(72)
    p1.font.bold = True
    p1.font.color.rgb = WHITE
    p1.alignment = PP_ALIGN.CENTER

    subtitle1 = slide1.shapes.add_textbox(Inches(1), Inches(4.5), Inches(14), Inches(2))
    tf1_sub = subtitle1.text_frame
    tf1_sub.text = "French news is fragmented.\nReaders never see the other side."
    p1_sub = tf1_sub.paragraphs[0]
    p1_sub.font.size = Pt(36)
    p1_sub.font.color.rgb = RGBColor(200, 200, 200)
    p1_sub.alignment = PP_ALIGN.CENTER

    # Slide 2: The Concept
    slide2 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide2.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title2 = slide2.shapes.add_textbox(Inches(1), Inches(1.5), Inches(14), Inches(1.5))
    tf2 = title2.text_frame
    tf2.text = "Perspective"
    p2 = tf2.paragraphs[0]
    p2.font.size = Pt(88)
    p2.font.bold = True
    p2.font.color.rgb = WHITE
    p2.alignment = PP_ALIGN.CENTER

    tagline2 = slide2.shapes.add_textbox(Inches(1), Inches(3), Inches(14), Inches(1))
    tf2_tag = tagline2.text_frame
    tf2_tag.text = "See Every Side"
    p2_tag = tf2_tag.paragraphs[0]
    p2_tag.font.size = Pt(48)
    p2_tag.font.color.rgb = RGBColor(180, 180, 180)
    p2_tag.alignment = PP_ALIGN.CENTER

    spectrum2 = slide2.shapes.add_textbox(Inches(2), Inches(5), Inches(12), Inches(2))
    tf2_spec = spectrum2.text_frame
    tf2_spec.text = "Extrême-gauche → Centre → Extrême-droite"
    p2_spec = tf2_spec.paragraphs[0]
    p2_spec.font.size = Pt(36)
    p2_spec.font.color.rgb = WHITE
    p2_spec.alignment = PP_ALIGN.CENTER

    concept2 = slide2.shapes.add_textbox(Inches(1), Inches(7), Inches(14), Inches(1.5))
    tf2_con = concept2.text_frame
    tf2_con.text = "Aggregation with political context.\nOne story, every angle."
    p2_con = tf2_con.paragraphs[0]
    p2_con.font.size = Pt(28)
    p2_con.font.color.rgb = RGBColor(200, 200, 200)
    p2_con.alignment = PP_ALIGN.CENTER

    # Slide 3: Origin Story
    slide3 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide3.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title3 = slide3.shapes.add_textbox(Inches(1), Inches(2), Inches(14), Inches(1.5))
    tf3 = title3.text_frame
    tf3.text = "Inspired by Ground News"
    p3 = tf3.paragraphs[0]
    p3.font.size = Pt(64)
    p3.font.bold = True
    p3.font.color.rgb = WHITE
    p3.alignment = PP_ALIGN.CENTER

    body3 = slide3.shapes.add_textbox(Inches(2), Inches(4), Inches(12), Inches(3))
    tf3_body = body3.text_frame
    tf3_body.text = "Built for the French Media Ecosystem\n\n• Unique political identities\n• Distinct ownership models\n• Localized for France"
    p3_body = tf3_body.paragraphs[0]
    p3_body.font.size = Pt(32)
    p3_body.font.color.rgb = RGBColor(200, 200, 200)
    p3_body.alignment = PP_ALIGN.LEFT

    # Slide 4: Feed Demo
    slide4 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide4.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title4 = slide4.shapes.add_textbox(Inches(1), Inches(1), Inches(14), Inches(1.5))
    tf4 = title4.text_frame
    tf4.text = "The Feed"
    p4 = tf4.paragraphs[0]
    p4.font.size = Pt(72)
    p4.font.bold = True
    p4.font.color.rgb = WHITE
    p4.alignment = PP_ALIGN.CENTER

    body4 = slide4.shapes.add_textbox(Inches(2), Inches(3), Inches(12), Inches(5))
    tf4_body = body4.text_frame
    tf4_body.text = "✓ Hero story (featured)\n\n✓ Daily brief (top 2 stories)\n\n✓ Coverage chart (political breakdown)\n\n✓ Source count per story"
    p4_body = tf4_body.paragraphs[0]
    p4_body.font.size = Pt(36)
    p4_body.font.color.rgb = RGBColor(200, 200, 200)
    p4_body.line_spacing = 1.5

    # Slide 5: Story Detail Demo
    slide5 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide5.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title5 = slide5.shapes.add_textbox(Inches(1), Inches(1), Inches(14), Inches(1.5))
    tf5 = title5.text_frame
    tf5.text = "Story Detail"
    p5 = tf5.paragraphs[0]
    p5.font.size = Pt(72)
    p5.font.bold = True
    p5.font.color.rgb = WHITE
    p5.alignment = PP_ALIGN.CENTER

    body5 = slide5.shapes.add_textbox(Inches(2), Inches(3), Inches(12), Inches(5))
    tf5_body = body5.text_frame
    tf5_body.text = "✓ AI spectrum summary (Gemini)\n\n✓ Articles grouped by political lean\n\n✓ Ownership breakdown\n\n✓ Full context, zero bubbles"
    p5_body = tf5_body.paragraphs[0]
    p5_body.font.size = Pt(36)
    p5_body.font.color.rgb = RGBColor(200, 200, 200)
    p5_body.line_spacing = 1.5

    # Slide 6: Monetization + Impact
    slide6 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide6.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title6 = slide6.shapes.add_textbox(Inches(1), Inches(2), Inches(14), Inches(1.5))
    tf6 = title6.text_frame
    tf6.text = "Freemium Model"
    p6 = tf6.paragraphs[0]
    p6.font.size = Pt(64)
    p6.font.bold = True
    p6.font.color.rgb = WHITE
    p6.alignment = PP_ALIGN.CENTER

    body6 = slide6.shapes.add_textbox(Inches(2), Inches(4), Inches(12), Inches(3.5))
    tf6_body = body6.text_frame
    tf6_body.text = "5 stories free per session\n\nPremium: Unlimited access\n\nMission: Break filter bubbles"
    p6_body = tf6_body.paragraphs[0]
    p6_body.font.size = Pt(40)
    p6_body.font.color.rgb = RGBColor(200, 200, 200)
    p6_body.alignment = PP_ALIGN.CENTER
    p6_body.line_spacing = 1.5

    # Slide 7: Closing
    slide7 = prs.slides.add_slide(prs.slide_layouts[6])
    background = slide7.background
    fill = background.fill
    fill.solid()
    fill.fore_color.rgb = DARK_BG

    title7 = slide7.shapes.add_textbox(Inches(1), Inches(2.5), Inches(14), Inches(2))
    tf7 = title7.text_frame
    tf7.text = "Perspective"
    p7 = tf7.paragraphs[0]
    p7.font.size = Pt(96)
    p7.font.bold = True
    p7.font.color.rgb = WHITE
    p7.alignment = PP_ALIGN.CENTER

    tagline7 = slide7.shapes.add_textbox(Inches(1), Inches(4.5), Inches(14), Inches(1.5))
    tf7_tag = tagline7.text_frame
    tf7_tag.text = "See Every Side"
    p7_tag = tf7_tag.paragraphs[0]
    p7_tag.font.size = Pt(48)
    p7_tag.font.color.rgb = RGBColor(180, 180, 180)
    p7_tag.alignment = PP_ALIGN.CENTER

    cta7 = slide7.shapes.add_textbox(Inches(1), Inches(6.5), Inches(14), Inches(1))
    tf7_cta = cta7.text_frame
    tf7_cta.text = "Coming Soon"
    p7_cta = tf7_cta.paragraphs[0]
    p7_cta.font.size = Pt(36)
    p7_cta.font.color.rgb = RGBColor(150, 150, 150)
    p7_cta.alignment = PP_ALIGN.CENTER

    # Save
    output_path = "/Users/arthur/Desktop/Coding/Ground News France/Perspective/Presentation/Perspective_Presentation.pptx"
    prs.save(output_path)
    print(f"✅ Presentation saved: {output_path}")
    print("📊 7 slides created")
    print("⏱️  Designed for 2m30s delivery")

if __name__ == "__main__":
    create_presentation()
