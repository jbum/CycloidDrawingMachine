String saveFilename(String prefix)
{
  String sf = prefix + year() + "-" + month() + "-" + day() + "_" + hour() + "." + minute() + "." + second() + (svgMode? ".svg" : ".png");
  return sf;
}

void saveSnapshot(String prefix)
{
    String sf = saveFilename(prefix);
    saveSnapshotAs(sf);
    println("Frame saved as " + sf);
    // Feedback
    for (Gear g : activeGears) {
      println("Gear " + g.nom + " has " + g.teeth + " teeth");
    }
}

void saveSnapshotAs(String sf)
{
    if (svgMode) {
      // println("Saving Path to SVG " + sf);
      PrintWriter fw;
      fw = createWriter(sf);
      fw.println("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>");
      fw.println("<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">");
      fw.println("<svg width=\"100%\" height=\"100%\" viewBox=\"0 0 648 648\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xml:space=\"preserve\" xmlns:serif=\"http://www.serif.com/\" style=\"fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2;\">");
      fw.println(String.format("<g stroke=\"#%06x\" fill=\"none\" stroke-width=\"%.1f\" >",((int)penColor) & 0x00FFFFFF,(float) penWidth));
      fw.println(String.format("<path d=\"%s\" />",svgPath));
      fw.println("</g>\n</svg>");
      println(svgPath);
      fw.flush();
      fw.close();
    } else {
      PGraphics tmp = createGraphics(paper.width, paper.height);
      tmp.smooth();
      tmp.beginDraw();
      tmp.background(255);
      tmp.image(paper, 0, 0);
      tmp.endDraw();
      tmp.save(sf);
    }
}

String getSetupString()
{
  String ss = "Setup\t" + ((char) (65+ setupMode)) + "\n";
  ss += "Gear Teeth\t";
  for (int i = 0; i < setupTeeth[setupMode].length; ++i) {
    if (i > 0)  ss += "\t";
    ss += setupTeeth[setupMode][i];
  }
  ss += "\nMount Points\t";
  for (int i = 0; i < setupMounts[setupMode].length; ++i) {
    if (i > 0)  ss += "\t";
    ss += setupMounts[setupMode][i];
  }
  ss += "\n";
  ss += "Pen\t" + penRig.len + "\t" + penRig.angle + "°" + "\n";
  return ss;
}

int GCD(int a, int b) {
   if (b==0) return a;
   return GCD(b,a%b);
}


// Compute total turntable rotations for current drawing
int computeCyclicRotations() {
  int a = 1; // running minimum
  int idx = 0;
  for (Gear g : activeGears) {
    if (g.contributesToCycle && g != turnTable) {
      int ratioNom = turnTable.teeth;
      int ratioDenom = g.teeth;
      if (g.isMoving) { // ! cheesy hack for our orbit configuration, assumes anchorTable,anchorHub,orbit configuration
        ratioNom = turnTable.teeth * (activeGears.get(idx-1).teeth + g.teeth);
        ratioDenom = activeGears.get(idx-2).teeth * g.teeth;
        int gcd = GCD(ratioNom, ratioDenom);
        ratioNom /= gcd;
        ratioDenom /= gcd;
      }
      int b = min(ratioNom,ratioDenom) / GCD(ratioNom, ratioDenom);
      a = max(a,max(a,b)*min(a,b)/ GCD(a, b));
    }
    idx += 1;
  }
  return a;
}

void invertConnectingRod()
{
  if (selectedObject instanceof ConnectingRod) {
    ((ConnectingRod) selectedObject).invert();
  } else if (activeConnectingRods.size() == 1) {
    activeConnectingRods.get(0).invert();
  } else {
    println("Please select a connecting rod to invert");
  }
}

void completeDrawing()
{
    myFrameCount = 0;
    penRaised = true;
    int totalRotations = computeCyclicRotations();
    if (!isTweening)
      println("Total turntable cycles needed = " + totalRotations);
    int framesPerRotation = int(TWO_PI / crankSpeed);
    myLastFrame = framesPerRotation * totalRotations + 1;
    passesPerFrame = isRecording? 10 : 360*2; // this sets up each pass to do 1 cycle
    isMoving = true;
}

void clearPaper() 
{
    svgPath = "";
    paper.beginDraw();
    paper.clear();
    paper.endDraw();
}

void measureGears() {
  float[] sav = {0,0,0,0,0,0,0,0,0};
  int i = 0;
  for (Gear g : activeGears) {
      sav[i] = g.rotation;
      i++;
  }
  myFrameCount += 1;
  turnTable.crank(myFrameCount*crankSpeed); // The turntable is always the root of the propulsion chain, since it is the only required gear.
  i = 0;
  for (Gear g : activeGears) {
      sav[i] = g.rotation;
      i++;
      // Turntable should be crankSpeed
      println(g.teeth + ": " + (g.rotation - sav[i])/crankSpeed);
  }

}

void nudge(int direction, int kc)
{
  if (selectedObject != null) {
    selectedObject.nudge(direction, kc);
  }
}

void deselect() {
  if (selectedObject != null) {
    selectedObject.unselect();
    selectedObject = null;
  }
}

void advancePenColor(int direction) {
  penColorIdx = (penColorIdx + penColors.length + direction) % penColors.length;
  penColor = penColors[penColorIdx]; 
  paper.beginDraw();
  paper.stroke(penColor);
  paper.endDraw();
  println("Pen color changed");
}

void advancePenWidth(int direction) {
  penWidthIdx = (penWidthIdx + penWidths.length + direction) % penWidths.length;
  penWidth = penWidths[penWidthIdx]; 
  paper.beginDraw();
  paper.strokeWeight(penWidth);
  paper.endDraw();
  println("Pen width set to " + penWidth);
}

void toggleOutputmode()
{
  svgMode = !svgMode;
  if (svgMode) {
    clearPaper();
    println("SVG ON - saved frames will be in SVG format");
  } else {
    println("SVG OFF - saved frames will be in PNG format");
  }
}

void toggleHiresmode()
{
  hiresMode = !hiresMode;
  PGraphics oldPaper = paper; 
  if (hiresMode) {
    paperScale = 2;
    println("Hires ON - saved frames are twice the size, drawings are 4 times as slow");
  }
  else {
    paperScale = 1;
    println("Hires OFF");
  }
  paperWidth = 9*inchesToPoints*paperScale;
  paper = createGraphics(int(paperWidth), int(paperWidth));
  paper.smooth(8);
  clearPaper();
  paper.beginDraw();
  paper.image(oldPaper,0,0,paper.width,paper.height);
  paper.endDraw();
  penRaised = true;
}




void saveSettings() {
  // default filename "setup_" + (char)('A' + setupMode) + "_override.txt"
  selectOutput("Select a file to save settings to:", "saveCallback");
  // println("Oname = " + oName);
}

void saveCallback(File fileSelection) 
{
  if (fileSelection == null) {
    println("Canceled");
    return;
  }
  JSONObject settings = new JSONObject();
  settings.setInt("layout", setupMode);

  JSONArray gears = new JSONArray();
  for (int i = 0; i < setupTeeth[setupMode].length; ++i) {
    gears.setInt(i, setupTeeth[setupMode][i]);
  }
  settings.setJSONArray("gears", gears);

  JSONArray mounts = new JSONArray();
  for (int i = 0; i < setupMounts[setupMode].length; ++i) {
    mounts.setFloat(i, setupMounts[setupMode][i]);
  }
  settings.setJSONArray("mounts", mounts);

  JSONArray invs = new JSONArray();
  for (int i = 0; i < setupInversions[setupMode].length; ++i) {
    invs.setBoolean(i, setupInversions[setupMode][i]);
  }
  settings.setJSONArray("inversions", invs);

  JSONObject penRigSetup = new JSONObject();
  penRigSetup.setFloat("length", setupPens[setupMode][0]);
  penRigSetup.setFloat("angle", setupPens[setupMode][1]);
  settings.setJSONObject("penrig", penRigSetup);

  saveJSONObject(settings, fileSelection.getAbsolutePath());
}

void loadSettings() 
{
  selectInput("Select a file to load settings from:", "loadCallback");
  
}

void loadCallback(File fileSelection) 
{
  if (fileSelection == null) {
    println("Canceled");
    return;
  }
  JSONObject settings = loadJSONObject(fileSelection.getAbsolutePath());
  if (settings == null) {
    println("Invalid settings file");
    return;
  }
  setupMode = settings.getInt("layout");

  JSONArray gears = settings.getJSONArray("gears");
  if (gears != null) {
    int ng = min(setupTeeth[setupMode].length, gears.size());
    for (int i = 0; i < ng; ++i) {
      setupTeeth[setupMode][i] = gears.getInt(i);
    }
  }

  JSONArray mounts = settings.getJSONArray("mounts");
  if (mounts != null) {
    int nm = min(setupMounts[setupMode].length, mounts.size());
    for (int i = 0; i < nm; ++i) {
      setupMounts[setupMode][i] = mounts.getFloat(i);
    }
  }

  JSONArray invs = settings.getJSONArray("inversions");
  if (invs != null) {
    int nm = min(setupInversions[setupMode].length, invs.size());
    for (int i = 0; i < nm; ++i) {
      setupInversions[setupMode][i] = invs.getBoolean(i);
    }
  }

  JSONObject penRigSetup = settings.getJSONObject("penrig");
  if (penRigSetup != null) {
    setupPens[setupMode][0] = penRigSetup.getFloat("length");
    setupPens[setupMode][1] = penRigSetup.getFloat("angle");
  }

  deselect();
  drawingSetup(setupMode, false);
}

void drawFulcrumLabels() {
    textFont(nFont);
    textAlign(CENTER);
    fill(64);
    stroke(92);
    strokeWeight(0.5);
    pushMatrix();
      translate(3.1*inchesToPoints, 10.23*inchesToPoints);
      rotate(PI/2);
      int nbrNotches = 39;
      float startNotch = 0.25*inchesToPoints;
      float notchIncr = 0.25*inchesToPoints;
      float minNotch = 0.9*inchesToPoints;
      float lilNotch = minNotch/2;
      float widIncr = 1.722*inchesToPoints/nbrNotches;
      float notchSize = minNotch;
      float notchX = -startNotch;
      for (int n = 0; n < 39; ++n) {
        line(notchX,0,notchX,n % 2 == 1? notchSize : lilNotch);
        if (n % 2 == 1) {
          text("" + (n/2+1),notchX,lilNotch); 
        }
        notchSize += widIncr;
        notchX -= notchIncr;
      }
    popMatrix();

}
