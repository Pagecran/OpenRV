module: ImageNameOverlay {
use rvtypes;
use commands;
use extra_commands;
use gl;
use rvui;
require gltext;

class: ImageNameOverlayMode : MinorMode
{
    bool _loggedRender;

    method: ImageNameOverlayMode (ImageNameOverlayMode;)
    {
        _loggedRender = false;
        this.init("image-name-overlay", nil, nil, nil);
    }

    method: render (void; Event event)
    {
        let domain = event.domain();

        if (!_loggedRender)
        {
            displayFeedback("Image Name Overlay render active", 3.0);
            _loggedRender = true;
        }

        let w = domain.x,
            h = domain.y;

        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();

        rvui.setupProjection(w, h, event.domainVerticalFlip());

        glPushAttrib(GL_ENABLE_BIT | GL_LINE_BIT | GL_COLOR_BUFFER_BIT | GL_CURRENT_BIT);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        gltext.size(12);

        string[] geomKeys = string[]{};
        int[] stackCounts = int[]{};
        string[] drawnKeys = string[]{};

        for_each (ri; renderedImages())
        {
            let group = nodeGroup(ri.node);
            if (group eq nil || nodeType(group) != "RVSourceGroup") continue;

            let geom = imageGeometry(ri.name);
            if (geom.size() < 4) continue;

            string label = uiName(ri.node);
            if (label == "") label = ri.node;

            let minX = math.min(math.min(geom[0].x, geom[1].x), math.min(geom[2].x, geom[3].x)),
                minY = math.min(math.min(geom[0].y, geom[1].y), math.min(geom[2].y, geom[3].y)),
                maxX = math.max(math.max(geom[0].x, geom[1].x), math.max(geom[2].x, geom[3].x)),
                maxY = math.max(math.max(geom[0].y, geom[1].y), math.max(geom[2].y, geom[3].y));

            string geomKey = "%d,%d,%d,%d" % (int(minX), int(minY), int(maxX), int(maxY));
            string drawKey = geomKey + "|" + label;

            bool alreadyDrawn = false;
            for_each (k; drawnKeys)
            {
                if (k == drawKey) alreadyDrawn = true;
            }

            if (alreadyDrawn) continue;

            drawnKeys.push_back(drawKey);

            int stackIndex = 0;
            bool foundKey = false;

            for_index (i; geomKeys)
            {
                if (geomKeys[i] == geomKey)
                {
                    stackIndex = stackCounts[i];
                    stackCounts[i] = stackIndex + 1;
                    foundKey = true;
                }
            }

            if (!foundKey)
            {
                geomKeys.push_back(geomKey);
                stackCounts.push_back(1);
            }

            let b       = gltext.bounds(label),
                textW   = b[0] + b[2],
                textH   = b[1] + b[3],
                padX    = 12,
                padY    = 10,
                x0      = maxX - textW - padX,
                y0      = minY + padY + stackIndex * (textH + 8);

            if (x0 < minX + padX) x0 = minX + padX;
            if (y0 + textH > maxY - padY) y0 = maxY - textH - padY;

            let bgLeft  = x0 - 6,
                bgRight = x0 + textW + 6,
                bgBot   = y0 - 4,
                bgTop   = y0 + textH + 4;

            glColor(Color(0.0, 0.0, 0.0, 0.55));
            glBegin(GL_QUADS);
            glVertex(bgLeft,  bgBot);
            glVertex(bgRight, bgBot);
            glVertex(bgRight, bgTop);
            glVertex(bgLeft,  bgTop);
            glEnd();

            gltext.color(Color(1.0, 1.0, 1.0, 1.0));
            gltext.writeAt(x0, y0, label);
        }

        glPopAttrib();
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix();
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
    }
}

\: createMode (Mode;)
{
    return ImageNameOverlayMode();
}
}
