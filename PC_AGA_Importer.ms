clearlistener()
struct obf (
	Magic="",
	BOffset=0,
	BSize=0,
	fn initStruct fstream = (
		Magic=""
		Magic+=bit.IntAsChar(readbyte fstream #unsigned)
		Magic+=bit.IntAsChar(readbyte fstream #unsigned)
		Magic+=bit.IntAsChar(readbyte fstream #unsigned)
		Magic+=bit.IntAsChar(readbyte fstream #unsigned)
		BSize=readlong fstream #unsigned
		BOffset=ftell fstream
		)
	)
struct _frame (
	name="",
	index_id=0,
	parent_id=0,
	matrix=(matrix3 1),
	fn initStruct f = (
		name=ReadFixedString f 64
		index_id = readlong f #unsigned
		matrix.row1 = [readfloat f,readfloat f,readfloat f]+readfloat f
		matrix.row2 = [readfloat f,readfloat f,readfloat f]+readfloat f
		matrix.row3 = [readfloat f,readfloat f,readfloat f]+readfloat f
		matrix.row4 = [readfloat f,readfloat f,readfloat f]*readfloat f
		fseek f 0x28 #seek_cur
		parent_id = readlong f #unsigned
		fseek f 0xDC #seek_cur
		)
	)
fn ReadFixedString bstream fixedLen = (
	local str = ""
	for i = 1 to fixedLen do (
		str += bit.intAsChar (ReadByte bstream #unsigned)
		)
	str
	)
fn buildObj verts tverts faces = (
	local j,msh
	if verts.count>0 do (
		msh = mesh vertices:verts tverts:tverts faces:faces
		msh.numTVerts = tverts.count
		msh.displayByLayer = false
		msh.backfacecull = on
		buildTVFaces msh
		--convertTo msh PolyMeshObject
		for j = 1 to tverts.count do setTVert msh j tverts[j]
		for j = 1 to faces.count do setTVFace msh j faces[j]
		)
	msh
	)
fn readChunk f chk = (
	local mscale = 10.0
	local p = 0, i = 1, x = 1, er = 1, ty=0
	local matArray=#(), texArray=#()
	local matName ="", texName="", objName="", dirName=""
	local uvwArray=#(), faceArray=#(), vertArray=#()
	local ukn1=0,subMshCount=0,check=0,vSize=0,fCount=0
	local vx=0,vy=0,vz=0,nx=0,ny=0,nz=0,tu=0,tv=0,fa=1,fb=2,fc=1
	local fram = _frame()
	local boneArray=#(), FrameArray=#()
	format "Chunk:\t%\n" chk.Magic
	case chk.Magic of (
		"OBJM": (
			chk.BSize = 4
			)
		"MATE": (
			for x = 1 to (chk.BSize/140) do (
				matName=ReadFixedString f 16
				fseek f 124 #seek_cur
				append matArray matName
				)
			)
		"TEXT": (
			for x = 1 to (chk.BSize/204) do (
				texName=ReadFixedString f 32
				fseek f 172 #seek_cur
				append texArray texName
				)	
			)
		"MESH": (
			while (ftell f < (chk.BOffset + chk.BSize)) do (
				p = ftell f
				uvwArray=#()
				faceArray=#()
				vertArray=#()
				objName=readstring f
				nodeName=readstring f
				fseek f (p + 0x40) #seek_set
				readlong f #unsigned -- Object HASH
				subMshCount=readlong f #unsigned
				if subMshCount ==  1 do (
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					readlong f #unsigned
					vert_count=readlong f #unsigned
					face_count=readlong f #unsigned
					readlong f #unsigned
					fseek f 0x100 #seek_cur
					format "VertCount:\t%\tFaceCount:\t%\t@ 0x%\n" \
						vert_count face_count (bit.intAsHex((ftell f)as integer))
					for x = 1 to vert_count do (
						vx=readfloat f*mscale
						vy=readfloat f*mscale
						vz=readfloat f*mscale
						
						readfloat f
						
						nx=readfloat f
						ny=readfloat f
						nz=readfloat f
						
						tu=readfloat f
						tv=readfloat f
						
						readlong f #unsigned
						readfloat f
						readlong f #unsigned
						readfloat f
						readlong f #unsigned
						readlong f #unsigned
						append vertArray[vx,-vz,vy]
						append uvwArray[tu,1-tv,0]
						)
					for x = 1 to (face_count/3) do (
						fa=readshort f #unsigned
						fb=readshort f #unsigned
						fc=readshort f #unsigned
						append faceArray ([fa,fb,fc] +1)
						)
					buildObj vertArray uvwArray faceArray
					)

				)
			)
		"FRAM": (
			fseek f chk.BOffset #seek_set
			for ty = 1 to (chk.BSize/0x018C) do (
				fram.initStruct(f)
				format "Name:\t%\tIndex:\t%\tParent:\t%\n" \
					fram.name fram.index_id fram.parent_id
-- 				append FrameArray fram
-- 				append boneArray (
-- 					Dummy name:fram.name transform:fram.matrix
-- 					)
				)
-- 			for i = 1 to boneArray.count do (
-- 				if FrameArray[i].parent_id!=0 do (
-- 					x = 1
-- 					for er = 1 to FrameArray.count do (
-- 						if FrameArray[er].index_id == FrameArray[i].parent_id do (
-- 							x = er
-- 							)
-- 						)
-- 					boneArray[i].parent = boneArray[x]
-- 					)
-- 				)
			)
		"ANIM": (
			
			)
		"FOG ": (
			
			)
		DEFAULT: (
			format "Error:\n\tNew Chunk ID: [%]\n" chk.Magic
			EXIT
			)
		)
	fseek f (chk.BOffset + chk.BSize) #seek_set
	)
fn readFile filen = (
	local f
	local fSize = getFileSize filen
	local chunk=obf()
	if filen!=undefined and doesFileExist filen == true then (
		try(fclose f)catch()
		f = fopen filen "rb"
		while (ftell f <fSize) do (
			chunk.initStruct f
			readChunk f chunk
			)
		format "Last Read @ 0x%\n" (bit.intAsHex((ftell f)as integer))
		fclose f
		)
	else (
		format "Aborted\n"
		)
	)
delete $*
readFile(GetOpenFileName caption:"Select any File" types: "X Files (*.x)|*.x|All files (*.*)|*.*|")
-- readFile("G:\\_3DMODELS\\Ripped\\Illusion3DModels\\A_GA\\AGA_Files\\hibana.x")