{ lib
, fetchFromGitHub
, buildGoModule
, substituteAll
, iputils
}:
buildGoModule {
  pname = "ndpresponder";
  version = "unstable-2023-06-24";

  src = fetchFromGitHub {
    owner = "yoursunny";
    repo = "ndpresponder";
    rev = "4500a2591d01a7b8310c0d065a1877baf60934fe";
    hash = "sha256-3dXEvLU7Ue4I5ccEdAVi0Wk+aqmOPX6HhLURVDsyn9M=";
  };

  patches = [                                                                           
    (substituteAll {
      src = ./ping.patch;
      inherit iputils;
    })
  ];

  vendorHash = "sha256-qFwQnxLcoh328Q+4eU+ByU5wslzrPg746vunz8bluyg=";

  meta = {
    description = "IPv6 Neighbor Discovery Responder for KVM servers";
    homepage = "https://github.com/yoursunny/ndpresponder";
    license = lib.licenses.isc;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.tie ];
  };
}
