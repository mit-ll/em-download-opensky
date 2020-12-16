polygon.x=[0 4 7 5 1];    %Polygon x-coordinates
polygon.y=[0 -2 0 10 8];  %Polygon y-coordinates
NX=5;                     %Number of divisions in x direction
NY=3;                     %Number of divisions in y direction

PXY=DIVIDEXY(polygon,NX,NY); %Divide Polygon to smaller polygons set by grid

subplot(1,2,1);   %Plot original Polygon
for i=0:1:NX
    plot([i/NX*(max(polygon.x)-min(polygon.x))+min(polygon.x) i/NX*(max(polygon.x)-min(polygon.x))+min(polygon.x)],[min(polygon.y) max(polygon.y)],'g');
    hold on
end
for i=0:1:NY
    plot([min(polygon.x) max(polygon.x)],[i/NY*(max(polygon.y)-min(polygon.y))+min(polygon.y) i/NY*(max(polygon.y)-min(polygon.y))+min(polygon.y)],'g');
    hold on
end
plot([polygon.x polygon.x(1)],[polygon.y polygon.y(1)],'b*-');
hold off
daspect([1 1 1]);

subplot(1,2,2);   %Plot smaller polygons set by grid
for i=1:1:NX
for j=1:1:NY
    if not(isempty(PXY{i,j}))
    plot([PXY{i,j}.x PXY{i,j}.x(1)],[PXY{i,j}.y PXY{i,j}.y(1)],'ro-');
    end
hold on
end
end
hold off
daspect([1 1 1]);

