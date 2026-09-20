def buffers = cpg.method("<operator>.alloc")
    .callIn
    .flatMap { alloc =>
        for {
            size <- alloc.ast.isLiteral.headOption
            buf  <- alloc.ast.isIdentifier.headOption
        } yield (buf, size.code.toInt)
    }

buffers.foreach { case (buf, declaredSize) =>
    cpg.call.name("memcpy", "strncpy")
    .filter { sinkCall =>
        sinkCall.argument(3).isLiteral
    }
    .filter { sinkCall =>
        val accessSize = sinkCall.argument(3).code.toInt
        accessSize > declaredSize
    }
    .filter { sinkCall =>
        sinkCall
        .argument(1)
        .reachableBy(buf)
        .nonEmpty
    }
    .foreach { sinkCall =>
        println(
            s"${sinkCall.code} : buffer=$declaredSize access=${sinkCall.argument(3).code}"
        )
    }
}
