open Core

exception Invalid_configuration of string

type own_cert = Certificate.certificate * Nocrypto.RSA.priv

type config = {
  ciphers                 : Ciphersuite.ciphersuite list ;
  protocol_versions       : tls_version * tls_version ;
  hashes                  : Ciphersuite.hash_algorithm list ;
  (* signatures              : Packet.signature_algorithm_type list ; *)
  use_rekeying            : bool ;
  require_secure_rekeying : bool ;
  validator               : X509.Validator.t option ;
  peer_name               : string option ;
  own_certificate         : own_cert option ;
}

type rekeying = [ `No | `Yes | `Yes_require_secure ]

let supported_hashes =
  Ciphersuite.([ SHA512 ; SHA384 ; SHA256 ; SHA ; MD5 ])

let supported_ciphers = Ciphersuite.([
    TLS_RSA_WITH_AES_256_CBC_SHA ;
    TLS_DHE_RSA_WITH_AES_256_CBC_SHA ;
    TLS_RSA_WITH_AES_128_CBC_SHA ;
    TLS_DHE_RSA_WITH_AES_128_CBC_SHA ;
    TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA ;
    TLS_RSA_WITH_3DES_EDE_CBC_SHA ;
    TLS_RSA_WITH_RC4_128_SHA ;
    TLS_RSA_WITH_RC4_128_MD5
  ])

let invalid msg = raise (Invalid_configuration msg)

let validate_exn config =
  let (v_max, v_min) = config.protocol_versions in
  if v_max < v_min then invalid "bad version range" ;
  if config.require_secure_rekeying &&
     not config.use_rekeying
  then invalid "rekeying disabled but secure rekeying required" ;
  ( match config.hashes with
    | [] when v_max >= TLS_1_2 ->
        invalid "TLS 1.2 allowed but no hashes specified"
    | _ -> () )


let (<?>) opt def = match opt with Some x -> x | None -> def

let create ?ciphers
           ?version
           ?hashes
           ?rekeying
           ?validator
           ?peer_name
           ?certificate
           () =

  let (rekey, sec_rekey) =
    match rekeying with
    | None                     -> (true, true)
    | Some `No                 -> (false, false)
    | Some `Yes                -> (true, false)
    | Some `Yes_require_secure -> (true, true) in

  let config = {
    ciphers           = ciphers  <?> supported_ciphers ;
    protocol_versions = version  <?> (TLS_1_2, TLS_1_0) ;
    hashes            = hashes   <?> supported_hashes ;
    use_rekeying      = rekey ;
    require_secure_rekeying = sec_rekey ;
    validator         = validator ;
    peer_name         = peer_name ;
    own_certificate   = certificate ;
  } in
  ( validate_exn config ; config )

(* |+ client +|
let open_connection ?cert ?host:server ~validator () =
  let open Config in
  let config =
  {
    default_config with
      validator = Some validator ;
      own_certificate = cert ;
      peer_name = server
  }
  in
  open_connection' config

|+ server +|
let listen_connection ?cert () =
  let open Config in
  let conf = { default_config with own_certificate = cert } in
  new_state conf `Server *)
