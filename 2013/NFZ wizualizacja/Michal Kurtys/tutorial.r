

Dane:
Informacje o kolejkach zapisane s� w plikach xls (excel).
Na ka�de wojw�dztwo przypada ich kilka. Nas teraz b�dzie interesowa� tylko ten zawieraj�cy AOS.
Jest wi�c 16 plik�w, kt�re wygl�daj� mniej-wi�cej w ten spos�b.
01_AOS_31072013.xls
02_AOS_31072013.xls
...
16_AOS_31072013.xls

Wojew�dztwa s� u�o�one alfabetycznie -
najmniejszy numer odpowiada wojew�dztwu dolno�l�skiemu, a najwi�kszy zachodniopomorskiemu.
Aby powi�za� numer z nazw� wojew�dztwa przygotowa�em plik wojew�dztwa.csv, w kt�rym s� one wypisane w nale�ytej kolejno�ci.

wojw�dztwa.csv
WOJ. DOLNO�L�SKIE
WOJ. KUJAWSKO-POMORSKIE
WOJ. LUBELSKIE
WOJ. LUBUSKIE
WOJ. ��DZKIE
WOJ. MA�OPOLSKIE
WOJ. MAZOWIECKIE
WOJ. OPOLSKIE
WOJ. PODKARPACKIE
WOJ. PODLASKIE
WOJ. POMORSKIE
WOJ. �L�SKIE
WOJ. �WI�TOKRZYSKIE
WOJ. WARMI�SKO-MAZURSKIE
WOJ. WIELKOPOLSKIE
WOJ. ZACHODNIOPOMORSKIE

Dane o granicach administracyjnych Polski pobra�em z Geoportalu. Ze wzgl�d�w licencyjnych pocz�tkowo chcia�em wykorzysta� OpenStreetMap.
Gotowe pliki shapefile oferuje m.in. geofabrik/cloudmade. Niestety, je�eli chodzi o Polsk� nie mia�em czego szuka� - wszystkie mapy by�y zdeformowane.
Mapy z Geoportalu nie s� dost�pne w formacie shapefile. Na szcz�cie dzi�ki instrukcjom we wpisie Pawe�a Wiechuckiego
(http://smarterpoland.pl/index.php/2013/05/poniewaz-mozemy-czyli-o-mapie-na-ktorej-widac-38-511-800-polakow/)
 ich w�asnor�czne stworzenie nie by�o trudne. 


Biblioteki:
maptools - funkcja readShapePoly - wczytanie pliku ShapeFile.
sp - manipulacje i wy�wietlanie danych kartograficznych.
rgeos,rgdal - potrzebujemy za�adowa� je, by skorzysta� z funkcji spTransform, kt�ra pozwala zmieni� uk�ad wsp�rz�dnych
FNN - funkcja get.knnx - regresja
SmarterPoland - dzi�ki temu, zawiera funkcj� getGoogleMapsAddress u�atwi pobranie wsp�rz�dnych punktu o okre�lonym adresie
Cairo - wyj�cie wykresu [TODO]
XLConnect - obs�uga plik�w excela

library(maptools)
library(sp)
library(rgeos)
library(SmarterPoland)
library(FNN)
library(rgdal)
library(Cairo)
library(XLConnect)


Zmiana katalogu roboczego. Wczytanie listy wojew�dztw.

Z ka�dego pliku "aos" odczytujemy dane, kt�re zaczynaj� si� w 3 wierszu(razem z nag��wkiem)  i maj� 9 kolumn. 
Postawnowi�em zmieni� nazwy kolumn, gdy� oryginalne by�y nies�ychanie d�ugie.
Dodatkowo tworzymy dodatkowe kolumny - ID i nazw� wojew�dztwa.

#
setwd("C:\\Users\\mic\\Documents\\eurostat\\nfzqueue\\new")
wojewodztwa = read.csv("wojewodztwa.csv", header=FALSE)
wojewodztwa$V1 = as.character(wojewodztwa$V1)


poradnie = data.frame()
for( i in 1:16 )
{
	filename = sprintf("%02d_AOS_31072013.xls", i)
	print(filename)
	wb = loadWorkbook( filename, create = FALSE)
	dane = readWorksheet(wb,sheet="Zestawienie", startRow = 3, startCol=0, endCol=8)
	dane$IDWojewodztwa = i
	dane$Wojewodztwo = wojewodztwa$V1[i]
	
	poradnie = rbind(poradnie, dane)
}

#zmiana nazwy kolumn
names(poradnie) = c(
"Nazwa.komorki.realizujacej",
"Kategoria",
"Nazwa",
"Nazwa.komorki",
"Adres",
"Liczba.oczekujacych",
"Liczba.skreslonych",
"Sredni.czas",
"ID.wojewodztwa",
"Wojewodztwo")
#

Pacjenci s� podzieleni przez NFZ na dwie grupy - "przypadek stabilny" i "przypadek ostry".
Wizualizowa� b�dziemy wy��cznie dane o przypadkach stabilnych.

Dalej dzielimy adres na cz�ci sk�adowe - nazwa miejscowo�ci i ulica razem z numerem numer lokalu.

#
poradnie = poradnie[which(poradnie$Kategoria == "przypadek stabilny"), ]
poradnie$Miejscowosc = sapply(strsplit(poradnie$Adres, "\n"), function(x) x[1] )
poradnie$Ulica = sapply(strsplit(poradnie$Adres, "\n"), function(x) x[2] )

poradnie$Sredni.czas = as.numeric(poradnie$Sredni.czas)
#


Pobieramy wsp�rz�dne wy��cznie miejscowo�ci w kt�rej znajduje si� poradnia.
Jest to znacznie szybsze, a z pewno�ci� nie potrzebujemy wi�kszej dok�adno�ci.
Po za tym Google ogranicza darmowy dost�p do us�ugi do 2500 zapyta� dziennie.

Konstruujemy wi�c tabel� zawieraj�c� nazw� miejscowo�ci w jednej kolumnie, a w drugiej wojew�dztwo w kt�rym si� ona znajduje.
Dodanie wojew�dztwa pomaga u�ci�li� zapytanie - istniej� przecie� miejscowo�ci, kt�re nosz� t� sam� nazw�.

Funkcja unique eliminuje zduplikowane wiersze.
W p�tli tworzymy now� zmienn� region, w kt�rej zapisujemy jedynie nazw� wojew�dztwa bez skr�tu "Woj." na pocz�tku.
Google Geocoding raczej nie trawi tego przedrostka.

Wojew�dztwo ��czymy z nazw� miejscowo�ci i przekazujemy do argumentu city funkcji getGoogleMapAddress.
Mo�e wygl�da� to dziwnie, ale zapytanie i tak zostanie skonstruowane poprawnie.
#
places_unique = data.frame( poradnie$Miejscowosc, poradnie$Wojewodztwo, check.names=FALSE)
places_unique = unique( places_unique )
names(places_unique) = c("Miejscowosc", "Wojewodztwo")
places_unique$Wojewodztwo = as.character(places_unique$Wojewodztwo)
places_unique$Miejscowosc = as.character(places_unique$Miejscowosc)

for( i in 1:nrow(places_unique) )
{
	region = strsplit( places_unique$Wojewodztwo[i], " " )[[1]][2]
	temp_coords = getGoogleMapsAddress(street="",city=paste(places_unique$Miejscowosc[i],",",region))

	places_unique$lat_wgs84[i] = temp_coords[1]
	places_unique$lng_wgs84[i] = temp_coords[2]
}
#

Zawczasu warto przygotowa� sobie wsp�rz�dne w uk�adzie, kt�ry jest bardziej przyjazny do zadania:
Tworzymy zmienn� typu SpatialPoints i okre�lamy ich uk�ad wsp�rz�dnych.
Wsp�rz�dne, kt�re pobrali�my s� w uk�adzie odniesienia WGS 84, znanym tak�e jako EPSG:4326

Nast�pnie zmieniamy uk�ad wsp�rz�dnych przy pomocy funkcji spTransform.

Ostatecznie ��czymy dwie tabele przy pomocy funkcji merge.
Wreszcie mamy wszystkie interesuj�ce nas warto�ci.

#
places_sp = SpatialPoints( cbind(places_unique$lng_wgs84, places_unique$lat_wgs84) )
proj4string(places_sp) = CRS("+init=epsg:4326")
places_sp = spTransform( places_sp, CRS("+init=epsg:2180"))


places_unique$lng = coordinates(places_sp)[,1]
places_unique$lat = coordinates(places_sp)[,2]

poradnie = merge(poradnie, places_unique)
#

Wczytanie pliku shapefile, kt�ry zawiera granice administracyjne wojew�dztw.
Jest ju� w prawid�owym uk�adzie wsp�rz�dnych - wystarczy tylko go okre�li�.

#
wojewodztwa.shp = readShapePoly("geoportal\\woj.shp")
proj4string(wojewodztwa.shp)=CRS("+init=epsg:2180")
#

Funkcja generate_grid pos�u�y do wygenerowania kraty, kt�ra b�dzie pokrywa� powierzchni� okre�lonego pola.
Na obrazku wida� punkty kraty. W istocie s� to punkty, kt�re b�d� s�u�y�y jako punkty startowe linii.

Pierwszy argument funkcji to ilo�� kom�rek kraty w osi X.
Kom�rka kraty ma by� kwadratem, wi�c ich ilo�� w osi Y nie b�dzie przekazywana do funkcji.

Nast�pnie wyliczamy topologi� kraty. Przekazujemy:
-wsp�rz�dne dolnego, lewego rogu
-wymiary kom�rek
-ilo�� kom�rek
I na koniec zwracamy obiekt klasy SpatialGrid.

[krata.png]
#
generate_grid = function( cell_n_x=1000, sp_polygons)
{
	bbox_min = bbox(sp_polygons)[,1]
	bbox_max = bbox(sp_polygons)[,2]
	cell_width=((bbox_max-bbox_min)/cell_n_x)[1]
	cell_height=cell_width
	cell_n_y = ceiling(((bbox_max-bbox_min)/cell_height)[2])


	gt = GridTopology( bbox_min, c(cell_width,cell_height), c(cell_n_x,cell_n_y)  )
	sg = SpatialGrid(gt, CRS("+init=epsg:2180"))
	return(sg)
}


Jak by�o wida� na obrazku, cz�� punkt�w kraty znajduje si� poza granicami kraju.
Funkcja which_cells_inside zwaraca indeksy kom�rek kraty, kt�re znajduj� si� wewn�trz obiektu SpatialPolygons.

Wykorzystamy do tego funkcj� over. Dla argument�w SpatialPoints i SpatialPolygons funkcja zwraca wektor o d�ugo�ci r�wnej ilo�ci punkt�w.
Warto�ci wektora m�wi� o tym, wewn�trz kt�rego wielok�ta znajduje si� punkt.
Tych mamy 16 - odpowiadaj� wojew�dztwom.

Je�eli jest poza jakimkolwiek wielok�tem sk�adowym to danemu punktowi odpowiada� b�dzie warto�� NA.

Szczeg�owo wielok�t sk�adowy to obiekt klasy Polygons:
#
> class(wojewodztwa.shp)
[1] "SpatialPolygonsDataFrame"
attr(,"package")
[1] "sp"
> class(wojewodztwa.shp@polygons)
[1] "list"
> class(wojewodztwa.shp@polygons[[1]])
[1] "Polygons"
attr(,"package")
[1] "sp"
> length(wojewodztwa.shp@polygons)
[1] 16
#


#
which_cells_inside = function( sp_grid, sp_polygons)
{
	grid_coords = coordinates(sp_grid)
	grid_points = SpatialPoints(grid_coords, CRS( proj4string(sp_grid)) )
	inside = over( grid_points, sp_polygons)
	proj4string(grid_points) = proj4string(wojewodztwa.shp)
	inside = which( inside$ID1 > 0 )
	return(inside)
}
#

Generowanie linii. W argumentach znajduje si� zmienna cell_distance, kt�ra m�wi co ile kom�rek kraty b�dzie znajdowa� si� pocz�tek linii.
Gdy pisa�em kod uzna�em, �e by� mo�e takie rozwi�zanie si� przyda. Teraz jestem pewien, �e bardziej elegancko by�oby genenerowa� mniejsz� krat�.
Co z reszt� ka�dy zauwa�y.

Zwracamy obiekt typu SpatialLines. Strunkura obiekt�w (Spatial)Line(s) jest podobna do Polygons.

Przypominam, �e linie rysujemy od punktu kraty do najbli�szej przychodni.
Musimy wi�c wiedzie�, kt�ra jest najbli�sza.
Przekazujemy wi�c macierz knn_indices w kt�rej b�dzie to zapisane.

sp_points to obiekt typu SpatialPoints, zawieraj�cy list� przychodni.

cell_subset ogranicza krat�, tak by linie by�y prowadzone tylko z wewn�trz kraju. 


generate_lines = function( knn_indices, sp_grid, sp_points, cell_distance=1, cell_subset=NULL )
{
	cell_n_x = sg@grid@cells.dim[1]
	cell_n_y = sg@grid@cells.dim[2]
	#macierz ktora zawiera indeksy komorek w ktorych zaczynaja sie linie
	line_anchors = matrix(nrow=floor(cell_n_y/cell_distance), ncol=floor(cell_n_x/cell_distance))
	for( i in 1:nrow(line_anchors))
	{
		line_anchors[i,] = seq(cell_distance, cell_n_x, by= cell_distance) +
						  rep(cell_n_x*cell_distance*i,floor(cell_n_x/cell_distance))
	}
	#tylko te linie ktorych poczatek jest w wybranych komorkach
	#na przyklad wewnatrz kraju
	line_anchors = intersect(line_anchors, cell_subset)
	
	#konstrukcja obiektow biblioteki sp
	line_starts = coordinates(sp_grid)[line_anchors,]
	closest_medic_idx = knn_indices[line_anchors,1]
	
	line_stops = coordinates(sp_points)[closest_medic_idx,]
	line_list = sapply( 1:nrow(line_starts), function(x) Line( rbind( line_starts[x,], line_stops[x,])) )
	line_obj = Lines(line_list, ID="a")
	sp_lines_obj = SpatialLines( list(line_obj) )

	return(sp_lines_obj)
}


Odpalamy funkcje.
W p�tli przejdziemy po kolei po ka�dym typie poradni.
Wewn�trz niej wybierzemy interesuj�ce nas wiersze w tabeli poradnie.
Dzi�ki bibliotece Cairo �atwo zapiszemy wykres w wysokiej rozdzielczo�ci.
get.knnx jest funkcj� obliczaj�c� regresj� k-s�siad�w.
W pierwszym arguemenie jest zbi�r danych, w drugim zbi�r zapyta�.
W tej sytuacji interesuje nas wy��cznie najbli�szy s�siad, wi�c k wynosi 1.
Zwraca dwie macierze - w pierwszej zapisuje indeksy najbli�szych s�siad�w, a w drugiej odleg�o�ci.


#wczytanie danych, etc..
#kod
sg = generate_grid( cell_n_x=100, wojewodztwa.shp)
inside_poland = which_cells_inside( sg, wojewodztwa.shp)


for( specialist_type in unique( (poradnie$Nazwa.komorki.realizujacej) ) )
{
	print(specialist_type)
	flush.console()
	specialist = poradnie[which(poradnie$Nazwa.komorki.realizujacej == specialist_type),]
	specialist_sp = SpatialPoints( cbind( specialist$lng, specialist$lat) ,CRS("+init=epsg:2180") )

	knn_res = get.knnx( specialist_sp@coords, coordinates(sg), k = 1 )
	
	sp_lines_obj = generate_lines( knn_res[[1]], sg, specialist_sp, cell_distance=1, cell_subset=inside_poland )
	
	Cairo(900, 700, file=paste(specialist_type,".png",sep=""), type="png", bg="white")
	plot(wojewodztwa.shp)
	plot(sp_lines_obj,add=T)
	#plot(specialist_sp,col="blue",lwd=2, add=T)
	title(main=specialist_type)
	dev.off()
}


Hidden track. Tworzenie map "kolorowych". Tworzymy troch� bardziej g�st� krat�.
Nast�pnie uzyskujemy punkty kraty i zmieniamy ich uk�ad wsp�rz�dnych do WGS 84.

Jest to niezb�dne - dla uk�adu wsp�rz�dnych epsg:2180 funkcja spDistsN1 nie zwraca�� odleg�o�ci w kilometrach. 


sg = generate_grid( cell_n_x=500, wojewodztwa.shp)
inside_poland = which_cells_inside( sg, wojewodztwa.shp)

grid_points_wgs84 = SpatialPoints( coordinates(sg), CRS(proj4string(sg)))
grid_points_wgs84 = spTransform(grid_points_wgs84, CRS("+init=epsg:4326"))
gp_coords = coordinates(grid_points_wgs84)

for( specialist_type in unique( (poradnie$Nazwa.komorki.realizujacej) ) )
{
	print(specialist_type)
	flush.console()
	specialist = poradnie[which(poradnie$Nazwa.komorki.realizujacej == specialist_type),]
	specialist_sp = SpatialPoints( cbind( specialist$lng, specialist$lat) ,CRS("+init=epsg:2180") )
	specialist_coords_wgs84 = cbind( specialist$lng_wgs84, specialist$lat_wgs84)

	#knn_res = get.knnx( specialist_sp@coords, coordinates(sg), k = ifelse(nrow(specialist)>10, 10, nrow(specialist) ))
	knn_res = get.knnx( specialist_sp@coords, coordinates(sg), k = 1)
	
	knn_indices = knn_res[[1]]
	km_distances =  matrix( nrow=nrow( knn_indices ), ncol=ncol(knn_indices))
	closest_coords = apply( knn_indices, c(1,2), function(x) specialist_coords_wgs84[x,])
	closest_coords = matrix( closest_coords, ncol = 2, byrow=TRUE ) #2*ncol(knn_indices)
	
	for (rowID in 1:nrow( knn_indices ) )
	{
		pts = matrix(closest_coords[rowID,],ncol=2)

		p = gp_coords[rowID,]
		km_distances[rowID,] = spDistsN1(pts, p, TRUE)
	}
	closest_distance = km_distances[,1]
	sg_df = SpatialGridDataFrame( sg, data.frame(closest_distance))
	
	#obszar po�o�ony poza granicami kraju ma mie� kolor bia�y
	sg_df@data$closest_distance[-inside_poland]=0
	#80 jest g�rn� granic� warto�ci na wykresie
	sg_df@data$closest_distance[ sg_df@data$closest_distance>80] = 80
	
	Cairo(900, 700, file=paste(specialist_type,"_c",".png",sep=""), type="png", bg="white")
	print(spplot( sg_df, panel = function(x,y,...){
	panel.gridplot(x,y,...,  )
	sp.polygons( wojewodztwa.shp )
	sp.points( specialist_sp, pch=".", col="black" )
	}, at=c(1:80), col.regions = rev(heat.colors(100)), main=specialist_type))
	dev.off()
	
}
[Poradnia Pulmonologiczna.png]
#

By�o to m�j pierwszy "wi�kszy" projekt w R. Z pewno�ci� wiele rozwi�za� nie jest najlepszych, ale mimo wszystko mam nadziej�, �e ten wpis b�dzie pomocny.




