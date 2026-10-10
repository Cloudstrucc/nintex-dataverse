import {PDFDocument, rgb, StandardFonts} from 'pdf-lib';
// Build a simple one-page "agreement" PDF with a party logo (colored circle + initials) top-right.
export async function brandedPdf(party, color){
  const doc=await PDFDocument.create();
  const page=doc.addPage([612,792]);
  const font=await doc.embedFont(StandardFonts.Helvetica);
  const bold=await doc.embedFont(StandardFonts.HelveticaBold);
  const [r,g,b]=color;
  // logo: filled circle top-right with party initials
  page.drawCircle({x:540,y:740,size:34,color:rgb(r,g,b)});
  const initials=party.split(/\s+/).map(w=>w[0]).join('').slice(0,3).toUpperCase();
  page.drawText(initials,{x:540-font.widthOfTextAtSize(initials,16)/2,y:734,size:16,font:bold,color:rgb(1,1,1)});
  // title + body
  page.drawText('Party Participation Agreement',{x:56,y:720,size:20,font:bold,color:rgb(0.1,0.15,0.25)});
  page.drawText(party,{x:56,y:694,size:13,font,color:rgb(r,g,b)});
  page.drawText('This agreement is entered into as of the date of last signature.',{x:56,y:650,size:11,font,color:rgb(0.2,0.2,0.2)});
  page.drawText('Signature:',{x:56,y:150,size:11,font:bold,color:rgb(0.2,0.2,0.2)});
  const bytes=await doc.save();
  return Buffer.from(bytes).toString('base64');
}
// If run directly, write a sample
if(import.meta.url===`file://${process.argv[1]}`){
  const b64=await brandedPdf('Green Future Party',[0.11,0.5,0.2]);
  console.log('base64 length',b64.length);
  const {writeFileSync}=await import('fs'); writeFileSync('/tmp/branded.b64',b64);
  console.log('wrote /tmp/branded.b64');
}
